<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
try {

    String user_id = param(request, jsonBody, "user_id");

    String sql =
    "SELECT v.id as venta_id, v.fecha, " +
    "j.titulo, vd.precio, vd.cantidad " +
    "FROM ventas v " +
    "INNER JOIN venta_detalle vd ON vd.venta_id = v.id " +
    "INNER JOIN juegos j ON j.id = vd.juego_id " +
    "WHERE v.usuario_id=? " +
    "ORDER BY v.fecha DESC";

    PreparedStatement ps = con.prepareStatement(sql);
    ps.setString(1, user_id);

    ResultSet rs = ps.executeQuery();

    StringBuilder json = new StringBuilder("[");
    boolean first = true;

    while(rs.next()) {

        if(!first) json.append(",");

        json.append("{")
        .append("\"venta_id\":\"").append(rs.getString("venta_id")).append("\",")
        .append("\"fecha\":\"").append(rs.getString("fecha")).append("\",")
        .append("\"titulo\":\"").append(rs.getString("titulo")).append("\",")
        .append("\"precio\":").append(rs.getDouble("precio")).append(",")
        .append("\"cantidad\":").append(rs.getInt("cantidad"))
        .append("}");

        first = false;
    }

    json.append("]");

    out.print(json.toString());

} catch(Exception e){
    out.print("{\"error\":\""+e.getMessage().replace("\"", "")+"\"}");
}
%>