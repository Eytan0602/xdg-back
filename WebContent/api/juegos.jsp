<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%!
private String escapeJson(String str) {
    if(str == null) return "";

    return str
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}
%>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String metodo = request.getMethod();

try {

    if("GET".equals(metodo)) {

        String id = param(request, jsonBody, "id");
        String q = param(request, jsonBody, "q");
        String categoriaId = param(request, jsonBody, "categoria_id");

        // =========================
        // 1. BUSCAR POR ID
        // =========================
        if(id != null && !id.trim().isEmpty()) {

            String sql = "SELECT * FROM juegos WHERE id=?";
            PreparedStatement ps = con.prepareStatement(sql);
            ps.setInt(1, Integer.parseInt(id));

            ResultSet rs = ps.executeQuery();

            if(rs.next()) {

                String titulo = escapeJson(rs.getString("titulo"));
                String desc   = escapeJson(rs.getString("descripcion"));
                String slug   = escapeJson(rs.getString("slug"));
                String img    = escapeJson(rs.getString("imagen_url"));
                String vid    = escapeJson(rs.getString("video_url"));
                String fecha  = escapeJson(rs.getString("fecha_lanzamiento"));

                out.print("{");
                out.print("\"id\":" + rs.getInt("id") + ",");
                out.print("\"titulo\":\"" + titulo + "\",");
                out.print("\"slug\":\"" + slug + "\",");
                out.print("\"descripcion\":\"" + desc + "\",");
                out.print("\"imagen_url\":\"" + img + "\",");
                out.print("\"video_url\":\"" + vid + "\",");
                out.print("\"fecha_lanzamiento\":\"" + fecha + "\",");
                out.print("\"precio\":" + rs.getDouble("precio"));
                out.print("}");
            } else {
                out.print("{}");
            }
        }

        // =========================
        // 2. BUSCADOR / FILTRO POR CATEGORÍA
        // =========================
        else {

            StringBuilder sql = new StringBuilder("SELECT * FROM juegos");

            boolean firstFilter = true;

            if(categoriaId != null && !categoriaId.trim().isEmpty()) {
                sql.append(" WHERE id IN (");
                sql.append("SELECT juego_id FROM juego_categoria WHERE categoria_id=?");
                sql.append(")");

                firstFilter = false;
            }

            if(q != null && !q.trim().isEmpty()) {

                if(firstFilter) {
                    sql.append(" WHERE titulo ILIKE ?");
                } else {
                    sql.append(" AND titulo ILIKE ?");
                }
            }

            sql.append(" ORDER BY id DESC");

            PreparedStatement ps = con.prepareStatement(sql.toString());

            int index = 1;

            if(categoriaId != null && !categoriaId.trim().isEmpty()) {
                ps.setInt(index++, Integer.parseInt(categoriaId));
            }

            if(q != null && !q.trim().isEmpty()) {
                ps.setString(index++, "%" + q + "%");
            }

            ResultSet rs = ps.executeQuery();

            StringBuilder json = new StringBuilder("[");
            boolean first = true;

            while(rs.next()) {

                if(!first) {
                    json.append(",");
                }

                String titulo = escapeJson(rs.getString("titulo"));
                String desc   = escapeJson(rs.getString("descripcion"));
                String slug   = escapeJson(rs.getString("slug"));
                String img    = escapeJson(rs.getString("imagen_url"));
                String vid    = escapeJson(rs.getString("video_url"));
                String fecha  = escapeJson(rs.getString("fecha_lanzamiento"));

                json.append("{")
                    .append("\"id\":").append(rs.getInt("id")).append(",")
                    .append("\"titulo\":\"").append(titulo).append("\",")
                    .append("\"slug\":\"").append(slug).append("\",")
                    .append("\"descripcion\":\"").append(desc).append("\",")
                    .append("\"imagen_url\":\"").append(img).append("\",")
                    .append("\"video_url\":\"").append(vid).append("\",")
                    .append("\"fecha_lanzamiento\":\"").append(fecha).append("\",")
                    .append("\"precio\":").append(rs.getDouble("precio"))
                    .append("}");

                first = false;
            }

            json.append("]");

            out.print(json.toString());
        }
    }

} catch(Exception e){

    String error = escapeJson(e.getMessage());

    out.print("{");
    out.print("\"error\":\"" + error + "\"");
    out.print("}");
}
%>