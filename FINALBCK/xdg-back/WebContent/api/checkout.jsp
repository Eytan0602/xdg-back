<%@ page import="java.sql.*, java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%
response.setHeader("Access-Control-Allow-Origin", "http://localhost:4321");
response.setHeader("Access-Control-Allow-Credentials", "true");
response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
response.setHeader("Access-Control-Allow-Headers", "Content-Type");

if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
    response.setStatus(200);
    return;
}
%>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%!
private String esc(String s) {
    if (s == null) return "";
    return s.replace("\\", "\\\\").replace("\"", "\\\"")
            .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t");
}
%>

<%
Map<String,String> jsonBody = parseJsonBody(request);

try {

    // usuario_id = quien paga y tiene el carrito
    // destinatario_id = opcional; si viene, es un regalo
    String usuario_id = param(request, jsonBody, "user_id");
    String destinatario_id = param(request, jsonBody, "destinatario_id");

    if (usuario_id == null) {
        out.print("{\"error\":\"missing user_id\"}");
        return;
    }

    boolean esRegalo = destinatario_id != null && !destinatario_id.trim().isEmpty();

    // A quién le "queda" el juego en su biblioteca: el destinatario si es regalo, si no, el propio comprador.
    String beneficiario_id = esRegalo ? destinatario_id.trim() : usuario_id;

    con.setAutoCommit(false);

    // =========================
    // 0. SI ES REGALO, VALIDAR QUE EL DESTINATARIO EXISTA Y NO SE REGALE A SÍ MISMO
    // =========================
    if (esRegalo) {

        if (beneficiario_id.equals(usuario_id)) {
            out.print("{\"success\":false,\"message\":\"No puedes regalarte el juego a ti mismo.\"}");
            con.rollback();
            return;
        }

        PreparedStatement psDestino = con.prepareStatement(
            "SELECT id FROM usuarios WHERE id = ? " +
            "AND (eliminado IS NULL OR eliminado = FALSE)"
        );
        psDestino.setString(1, beneficiario_id);
        ResultSet rsDestino = psDestino.executeQuery();
        boolean destinoValido = rsDestino.next();
        rsDestino.close(); psDestino.close();

        if (!destinoValido) {
            out.print("{\"success\":false,\"message\":\"El usuario destinatario del regalo no existe.\"}");
            con.rollback();
            return;
        }
    }

    // =========================
    // 1. OBTENER ITEMS (siempre del carrito de quien paga)
    // =========================
    String carritoSQL =
        "SELECT cd.juego_id, cd.cantidad, cd.precio_unitario " +
        "FROM carrito_detalle cd " +
        "INNER JOIN carritos c ON c.id = cd.carrito_id " +
        "WHERE c.usuario_id=?";

    PreparedStatement psCarrito = con.prepareStatement(carritoSQL);
    psCarrito.setString(1, usuario_id);
    ResultSet items = psCarrito.executeQuery();

    class Item {
        String juegoId;
        int cantidad;
        double precio;

        Item(String j, int c, double p) {
            juegoId = j;
            cantidad = c;
            precio = p;
        }
    }

    List<Item> itemList = new ArrayList<Item>();

    while (items.next()) {
        itemList.add(new Item(
            items.getString("juego_id"),
            items.getInt("cantidad"),
            items.getDouble("precio_unitario")
        ));
    }

    if (itemList.isEmpty()) {
        out.print("{\"success\":false,\"message\":\"cart empty\"}");
        return;
    }

    // =========================
    // 1.5 VALIDAR QUE EL BENEFICIARIO NO POSEA YA EL JUEGO
    // (se ignoran las filas 'enviado', porque esas no representan posesión real:
    //  son solo el registro/boleta de un regalo que el usuario hizo a otro)
    // =========================
    PreparedStatement psCheck = con.prepareStatement(
        "SELECT j.titulo FROM venta_detalle vd " +
        "JOIN ventas v ON vd.venta_id = v.id " +
        "JOIN juegos j ON vd.juego_id = j.id " +
        "WHERE v.usuario_id = ? AND vd.juego_id = CAST(? AS INTEGER) " +
        "AND (v.rol_regalo IS NULL OR v.rol_regalo <> 'enviado') " +
        "LIMIT 1"
    );

    for (Item it : itemList) {
        psCheck.setString(1, beneficiario_id);
        psCheck.setString(2, it.juegoId);
        ResultSet rsCheck = psCheck.executeQuery();
        if (rsCheck.next()) {
            String mensajeDuplicado = esRegalo
                ? "El usuario destinatario ya posee el juego '" + esc(rsCheck.getString("titulo")) + "'."
                : "Ya posees el juego '" + esc(rsCheck.getString("titulo")) + "' en tu biblioteca.";
            out.print("{\"success\":false,\"message\":\"" + mensajeDuplicado + "\"}");
            con.rollback();
            return;
        }
        rsCheck.close();
    }

    // =========================
    // 2. CREAR VENTA(S)
    // =========================
    String ventaCompradorId = null;     // fila que guarda la boleta del comprador
    String ventaBeneficiarioId = null;  // fila que representa la posesión del juego

    if (esRegalo) {
        // 2a. Fila del COMPRADOR: guarda la boleta, marcada como "regalo enviado"
        PreparedStatement ventaCompradorPS = con.prepareStatement(
            "INSERT INTO ventas(usuario_id, fecha, es_regalo, rol_regalo, relacionado_usuario_id, tiene_boleta) " +
            "VALUES(?, NOW(), TRUE, 'enviado', ?, TRUE) RETURNING id"
        );
        ventaCompradorPS.setString(1, usuario_id);
        ventaCompradorPS.setString(2, beneficiario_id);
        ResultSet keysComprador = ventaCompradorPS.executeQuery();
        if (keysComprador.next()) ventaCompradorId = keysComprador.getString(1);

        // 2b. Fila del RECEPTOR: el juego entra a su biblioteca, sin boleta
        PreparedStatement ventaReceptorPS = con.prepareStatement(
            "INSERT INTO ventas(usuario_id, fecha, es_regalo, rol_regalo, relacionado_usuario_id, tiene_boleta) " +
            "VALUES(?, NOW(), TRUE, 'recibido', ?, FALSE) RETURNING id"
        );
        ventaReceptorPS.setString(1, beneficiario_id);
        ventaReceptorPS.setString(2, usuario_id);
        ResultSet keysReceptor = ventaReceptorPS.executeQuery();
        if (keysReceptor.next()) ventaBeneficiarioId = keysReceptor.getString(1);

    } else {
        // Compra normal para uno mismo: una sola fila
        PreparedStatement ventaPS = con.prepareStatement(
            "INSERT INTO ventas(usuario_id, fecha) VALUES(?, NOW()) RETURNING id"
        );
        ventaPS.setString(1, usuario_id);
        ResultSet keys = ventaPS.executeQuery();
        if (keys.next()) ventaCompradorId = keys.getString(1);
        ventaBeneficiarioId = ventaCompradorId;
    }

    if (ventaCompradorId == null || ventaBeneficiarioId == null) {
        throw new Exception("No se pudo obtener el ID de la venta");
    }

    // =========================
    // 3. INSERTAR DETALLE VENTA (para cada fila de venta creada)
    // =========================
    PreparedStatement detPS = con.prepareStatement(
        "INSERT INTO venta_detalle(venta_id, juego_id, precio, cantidad) VALUES(?, CAST(? AS INTEGER), ?, ?)"
    );

    for (Item it : itemList) {
        detPS.setString(1, ventaCompradorId);
        detPS.setString(2, it.juegoId);
        detPS.setDouble(3, it.precio);
        detPS.setInt(4, it.cantidad);
        detPS.executeUpdate();

        if (!ventaBeneficiarioId.equals(ventaCompradorId)) {
            detPS.setString(1, ventaBeneficiarioId);
            detPS.setString(2, it.juegoId);
            detPS.setDouble(3, it.precio);
            detPS.setInt(4, it.cantidad);
            detPS.executeUpdate();
        }
    }

    // =========================
    // 4. LIMPIAR CARRITO (siempre el del comprador)
    // =========================
    PreparedStatement clPS = con.prepareStatement(
        "DELETE FROM carrito_detalle cd " +
        "USING carritos c " +
        "WHERE cd.carrito_id = c.id " +
        "AND c.usuario_id = ?"
    );
    clPS.setString(1, usuario_id);
    clPS.executeUpdate();

    // =========================
    // 5. ARMAR ITEMS PARA EL RECIBO (respuesta al comprador)
    // =========================
    StringBuilder itemsJson = new StringBuilder("[");
    boolean primerItem = true;
    PreparedStatement juegoInfoPS = con.prepareStatement(
        "SELECT titulo, precio as precio_original, fecha_lanzamiento FROM juegos WHERE id = CAST(? AS INTEGER)"
    );
    for (Item it : itemList) {
        juegoInfoPS.setString(1, it.juegoId);
        ResultSet rsJuego = juegoInfoPS.executeQuery();
        String titulo = "";
        double precioOriginal = it.precio;
        String fechaLanz = null;
        if (rsJuego.next()) {
            titulo = rsJuego.getString("titulo");
            precioOriginal = rsJuego.getDouble("precio_original");
            java.sql.Date fl = rsJuego.getDate("fecha_lanzamiento");
            fechaLanz = fl != null ? fl.toString() : null;
        }
        rsJuego.close();

        if (!primerItem) itemsJson.append(",");
        primerItem = false;
        itemsJson.append("{")
            .append("\"titulo\":\"").append(esc(titulo)).append("\",")
            .append("\"precio\":").append(it.precio).append(",")
            .append("\"precio_original\":").append(precioOriginal).append(",")
            .append("\"cantidad\":").append(it.cantidad).append(",")
            .append("\"fecha_lanzamiento\":").append(fechaLanz != null ? "\"" + fechaLanz + "\"" : "null")
            .append("}");
    }
    itemsJson.append("]");

    con.commit();

    out.print("{\"success\":true,\"venta_id\":\"" + ventaCompradorId + "\",\"items\":" + itemsJson.toString() + "}");

} catch (Exception e) {

    try { con.rollback(); } catch(Exception ex) {}

    e.printStackTrace();

    out.print("{\"error\":\"" + esc(e.toString()) + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>