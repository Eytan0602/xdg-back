<%@ page import="java.sql.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String method = request.getMethod();

try {

    // ==================================================
    // POST -> AGREGAR AL CARRITO
    // ==================================================
    if("POST".equals(method)) {

        String user = param(request, jsonBody, "user_id");
        String juegoIdParam = param(request, jsonBody, "juego_id");
        int cantidad = 1;

        if(user == null || juegoIdParam == null) {
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        if(param(request, jsonBody, "cantidad") != null) {
            cantidad = Integer.parseInt(param(request, jsonBody, "cantidad"));

            if(cantidad < 1) {
                cantidad = 1;
            }
        }

        int juego_id = Integer.parseInt(juegoIdParam);

        // buscar carrito
        String cartSql = "SELECT id FROM carritos WHERE usuario_id=?";
        PreparedStatement cartPs = con.prepareStatement(cartSql);
        cartPs.setString(1, user);

        ResultSet cartRs = cartPs.executeQuery();

        int carritoId;

        if(cartRs.next()) {

            carritoId = cartRs.getInt("id");

        } else {

            String insertCart = "INSERT INTO carritos(usuario_id) VALUES(?)";

            PreparedStatement insertCartPs =
                con.prepareStatement(insertCart, Statement.RETURN_GENERATED_KEYS);

            insertCartPs.setString(1, user);
            insertCartPs.executeUpdate();

            ResultSet keys = insertCartPs.getGeneratedKeys();

            if(keys.next()) {
                carritoId = keys.getInt(1);
            } else {
                out.print("{\"error\":\"cannot create cart\"}");
                return;
            }
        }

        // precio del juego
        String priceSql = "SELECT precio FROM juegos WHERE id=?";

        PreparedStatement pricePs = con.prepareStatement(priceSql);
        pricePs.setInt(1, juego_id);

        ResultSet priceRs = pricePs.executeQuery();

        if(!priceRs.next()) {
            out.print("{\"error\":\"game not found\"}");
            return;
        }

        double precio = priceRs.getDouble("precio");

        // ya existe?
        String detailSql =
            "SELECT id,cantidad FROM carrito_detalle WHERE carrito_id=? AND juego_id=?";

        PreparedStatement detailPs = con.prepareStatement(detailSql);

        detailPs.setInt(1, carritoId);
        detailPs.setInt(2, juego_id);

        ResultSet detailRs = detailPs.executeQuery();

        int updated = 0;

        if(detailRs.next()) {

            int actual = detailRs.getInt("cantidad");

            String updateSql =
                "UPDATE carrito_detalle SET cantidad=? WHERE id=?";

            PreparedStatement updatePs = con.prepareStatement(updateSql);

            updatePs.setInt(1, actual + cantidad);
            updatePs.setInt(2, detailRs.getInt("id"));

            updated = updatePs.executeUpdate();

        } else {

            String insertSql =
                "INSERT INTO carrito_detalle(carrito_id,juego_id,cantidad,precio_unitario) VALUES(?,?,?,?)";

            PreparedStatement insertPs = con.prepareStatement(insertSql);

            insertPs.setInt(1, carritoId);
            insertPs.setInt(2, juego_id);
            insertPs.setInt(3, cantidad);
            insertPs.setDouble(4, precio);

            updated = insertPs.executeUpdate();
        }

        out.print("{\"success\":"+(updated>0)+"}");

    }

    // ==================================================
    // GET -> VER CARRITO
    // ==================================================
    else if("GET".equals(method)) {

        String user = request.getParameter("user_id");

        if(user == null) {
            out.print("{\"error\":\"missing user_id\"}");
            return;
        }

        String sql =
            "SELECT " +
            "cd.id, " +
            "j.id as juego_id, " +
            "j.titulo, " +
            "j.imagen_url, " +
            "j.precio, " +
            "cd.cantidad, " +
            "(j.precio * cd.cantidad) as subtotal " +
            "FROM carritos c " +
            "INNER JOIN carrito_detalle cd ON c.id = cd.carrito_id " +
            "INNER JOIN juegos j ON j.id = cd.juego_id " +
            "WHERE c.usuario_id=?";

        PreparedStatement ps = con.prepareStatement(sql);

        ps.setString(1, user);

        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");

        boolean first = true;

        while(rs.next()) {

            if(!first) {
                json.append(",");
            }

            json.append("{")
                .append("\"detalle_id\":").append(rs.getInt("id")).append(",")
                .append("\"juego_id\":").append(rs.getInt("juego_id")).append(",")
                .append("\"titulo\":\"").append(rs.getString("titulo")).append("\",")
                .append("\"imagen_url\":\"").append(rs.getString("imagen_url") != null ? rs.getString("imagen_url") : "").append("\",")
                .append("\"precio\":").append(rs.getDouble("precio")).append(",")
                .append("\"cantidad\":").append(rs.getInt("cantidad")).append(",")
                .append("\"subtotal\":").append(rs.getDouble("subtotal"))
                .append("}");

            first = false;
        }

        json.append("]");

        out.print(json.toString());

    }

    // ==================================================
// DELETE -> ELIMINAR ITEM DEL CARRITO
// ==================================================
else if("DELETE".equals(method)) {

    String detalleId = param(request, jsonBody, "detalle_id");

    if(detalleId == null) {
        out.print("{\"error\":\"missing detalle_id\"}");
        return;
    }

    String sql = "DELETE FROM carrito_detalle WHERE id=?";
    PreparedStatement ps = con.prepareStatement(sql);
    ps.setInt(1, Integer.parseInt(detalleId));

    int r = ps.executeUpdate();
    out.print("{\"success\":" + (r > 0) + "}");
}

    else {

        out.print("{\"error\":\"invalid method\"}");

    }

} catch(Exception e) {

    out.print("{\"error\":\""+e.getMessage().replace("\"","")+"\"}");

}
%>