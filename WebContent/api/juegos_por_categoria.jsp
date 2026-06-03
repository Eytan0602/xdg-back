<%@ page import="java.sql.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>

<%
String categoriaId = request.getParameter("categoria_id");

if (categoriaId == null) {
    out.print("[]");
    return;
}

String sql =
"SELECT j.* " +
"FROM juegos j " +
"JOIN juego_categoria jc ON j.id = jc.juego_id " +
"WHERE jc.categoria_id = ?";

PreparedStatement ps = con.prepareStatement(sql);
ps.setInt(1, Integer.parseInt(categoriaId));

ResultSet rs = ps.executeQuery();

StringBuilder json = new StringBuilder("[");
boolean first = true;

while (rs.next()) {
    if (!first) json.append(",");

    json.append("{")
        .append("\"id\":").append(rs.getInt("id")).append(",")
        .append("\"titulo\":\"").append(rs.getString("titulo")).append("\",")
        .append("\"descripcion\":\"").append(rs.getString("descripcion")).append("\",")
        .append("\"precio\":").append(rs.getDouble("precio")).append(",")
        .append("\"imagen_url\":\"").append(rs.getString("imagen_url")).append("\",")
        .append("\"fecha_lanzamiento\":\"").append(rs.getString("fecha_lanzamiento")).append("\"")
        .append("}");

    first = false;
}

json.append("]");
out.print(json.toString());
%>