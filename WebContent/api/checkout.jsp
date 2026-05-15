<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
try {

    String usuario_id = param(request, jsonBody, "user_id");
    if(usuario_id == null) {
        out.print("{\"error\":\"missing user_id\"}");
        return;
    }

    String ventaId = UUID.randomUUID().toString();

    String ventaSQL = "INSERT INTO ventas(id,usuario_id) VALUES(?,?)";
    PreparedStatement ventaPS = con.prepareStatement(ventaSQL);
    ventaPS.setString(1, ventaId);
    ventaPS.setString(2, usuario_id);
    ventaPS.executeUpdate();

    String carritoSQL =
    "SELECT cd.juego_id, cd.cantidad, cd.precio_unitario " +
    "FROM carrito_detalle cd " +
    "INNER JOIN carritos c ON c.id = cd.carrito_id " +
    "WHERE c.usuario_id=?";

    PreparedStatement ps = con.prepareStatement(carritoSQL);
    ps.setString(1, usuario_id);

    ResultSet items = ps.executeQuery();

    boolean hasItems = false;
    while(items.next()) {
        hasItems = true;
        String sql = "INSERT INTO venta_detalle(venta_id,juego_id,precio,cantidad) VALUES(?,?,?,?)";
        PreparedStatement det = con.prepareStatement(sql);
        det.setString(1, ventaId);
        det.setInt(2, items.getInt("juego_id"));
        det.setDouble(3, items.getDouble("precio_unitario"));
        det.setInt(4, items.getInt("cantidad"));
        det.executeUpdate();
    }

    if(!hasItems) {
        out.print("{\"success\":false,\"message\":\"cart empty\"}");
        return;
    }

    String clean =
    "DELETE FROM carrito_detalle " +
    "WHERE carrito_id = (SELECT id FROM carritos WHERE usuario_id=?)";

PreparedStatement cl = con.prepareStatement(clean);
cl.setString(1, usuario_id);
cl.executeUpdate();

    out.print("{\"success\":true,\"venta_id\":\""+ventaId+"\"}");

} catch(Exception e) {
    out.print("{\"error\":\"" + e.getMessage().replace("\"", "") + "\"}");
}
%>