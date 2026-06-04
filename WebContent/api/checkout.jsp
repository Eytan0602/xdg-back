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

<%
Map<String,String> jsonBody = parseJsonBody(request);

try {

    String usuario_id = param(request, jsonBody, "user_id");

    if (usuario_id == null) {
        out.print("{\"error\":\"missing user_id\"}");
        return;
    }

    con.setAutoCommit(false);

    // =========================
    // 1. OBTENER ITEMS
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
        items.getString("juego_id"),  // <-- getString, no getInt
        items.getInt("cantidad"),
        items.getDouble("precio_unitario")
    ));
}

    if (itemList.isEmpty()) {
        out.print("{\"success\":false,\"message\":\"cart empty\"}");
        return;
    }

   // =========================
// 2. CREAR VENTA
// =========================
PreparedStatement ventaPS = con.prepareStatement(
    "INSERT INTO ventas(usuario_id, fecha) VALUES(CAST(? AS UUID), NOW()) RETURNING id"
);

ventaPS.setString(1, usuario_id);
ResultSet keys = ventaPS.executeQuery();

String ventaId = null;
if (keys.next()) {
    ventaId = keys.getString(1);
}

if (ventaId == null) {
    throw new Exception("No se pudo obtener el ID de la venta");
}

    // =========================
    // 3. INSERTAR DETALLE VENTA
    // =========================
    PreparedStatement detPS = con.prepareStatement(
    "INSERT INTO venta_detalle(venta_id, juego_id, precio, cantidad) VALUES(CAST(? AS UUID), CAST(? AS INTEGER), ?, ?)"
);

    for (Item it : itemList) {
    detPS.setString(1, ventaId);
    detPS.setString(2, it.juegoId);
    detPS.setDouble(3, it.precio);
    detPS.setInt(4, it.cantidad);
    detPS.executeUpdate();
}

    // =========================
    // 4. LIMPIAR CARRITO
    // =========================
    PreparedStatement clPS = con.prepareStatement(
        "DELETE FROM carrito_detalle cd " +
        "USING carritos c " +
        "WHERE cd.carrito_id = c.id " +
        "AND c.usuario_id = ?"
    );

    clPS.setString(1, usuario_id);
    clPS.executeUpdate();

    con.commit();

    out.print("{\"success\":true,\"venta_id\":\"" + ventaId + "\"}");

} catch (Exception e) {

    try { con.rollback(); } catch(Exception ex) {}

    e.printStackTrace();

    out.print("{\"error\":\"" + e.toString().replace("\"","") + "\"}");
}
%>