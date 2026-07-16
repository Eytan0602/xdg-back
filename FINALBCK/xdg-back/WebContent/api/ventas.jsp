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
    "SELECT v.id as venta_id, v.fecha, v.es_regalo, v.rol_regalo, v.tiene_boleta, " +
    "ur.usuario as relacionado_usuario, ur.nombre as relacionado_nombre, " +
    "j.id as juego_id, j.titulo, j.imagen_url, vd.precio, vd.cantidad, j.precio as precio_original, j.fecha_lanzamiento " +
    "FROM ventas v " +
    "INNER JOIN venta_detalle vd ON vd.venta_id = v.id " +
    "INNER JOIN juegos j ON j.id = vd.juego_id " +
    "LEFT JOIN usuarios ur ON ur.id = v.relacionado_usuario_id " +
    "WHERE v.usuario_id=? " +
    "ORDER BY v.fecha DESC";

    PreparedStatement ps = con.prepareStatement(sql);
    ps.setString(1, user_id);

    ResultSet rs = ps.executeQuery();

    StringBuilder json = new StringBuilder("[");
    boolean first = true;

    while(rs.next()) {

        if(!first) json.append(",");

        String relacionadoUsuario = rs.getString("relacionado_usuario");
        String rolRegalo = rs.getString("rol_regalo");

        json.append("{")
        .append("\"venta_id\":\"").append(rs.getString("venta_id")).append("\",")
        .append("\"fecha\":\"").append(rs.getString("fecha")).append("\",")
        .append("\"es_regalo\":").append(rs.getBoolean("es_regalo")).append(",")
        .append("\"rol_regalo\":").append(rolRegalo != null ? "\"" + rolRegalo + "\"" : "null").append(",")
        .append("\"tiene_boleta\":").append(rs.getBoolean("tiene_boleta")).append(",")
        .append("\"relacionado_usuario\":").append(relacionadoUsuario != null ? "\"" + relacionadoUsuario.replace("\"","'") + "\"" : "null").append(",")
        .append("\"juego_id\":\"").append(rs.getString("juego_id")).append("\",")
        .append("\"titulo\":\"").append(rs.getString("titulo").replace("\"","'")).append("\",")
        .append("\"imagen_url\":\"").append(rs.getString("imagen_url") != null ? rs.getString("imagen_url").replace("\"","'") : "").append("\",")
        .append("\"precio\":").append(rs.getDouble("precio")).append(",")
        .append("\"cantidad\":").append(rs.getInt("cantidad")).append(",")
        .append("\"precio_original\":").append(rs.getDouble("precio_original")).append(",")
        .append("\"fecha_lanzamiento\":").append(rs.getDate("fecha_lanzamiento") != null ? "\"" + rs.getDate("fecha_lanzamiento").toString() + "\"" : "null")
        .append("}");

        first = false;
    }

    json.append("]");

    out.print(json.toString());

} catch(Exception e){
    out.print("{\"error\":\""+e.getMessage().replace("\"", "")+"\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>