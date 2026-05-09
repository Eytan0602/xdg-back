<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>
<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>
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
        if(id != null) {

            String sql = "SELECT * FROM juegos WHERE id=?";
            PreparedStatement ps = con.prepareStatement(sql);
            ps.setInt(1, Integer.parseInt(id));
            ResultSet rs = ps.executeQuery();

            if(rs.next()) {
                String desc  = rs.getString("descripcion")       != null ? rs.getString("descripcion").replace("\"","'")       : "";
                String slug  = rs.getString("slug")              != null ? rs.getString("slug")                                : "";
                String img   = rs.getString("imagen_url")        != null ? rs.getString("imagen_url")                         : "";
                String vid   = rs.getString("video_url")         != null ? rs.getString("video_url")                          : "";
                String fecha = rs.getString("fecha_lanzamiento") != null ? rs.getString("fecha_lanzamiento")                  : "";

                out.print("{");
                out.print("\"id\":"                  + rs.getInt("id")           + ",");
                out.print("\"titulo\":\""             + rs.getString("titulo")    + "\",");
                out.print("\"slug\":\""               + slug                      + "\",");
                out.print("\"descripcion\":\""        + desc                      + "\",");
                out.print("\"imagen_url\":\""         + img                       + "\",");
                out.print("\"video_url\":\""          + vid                       + "\",");
                out.print("\"fecha_lanzamiento\":\"" + fecha                     + "\",");
                out.print("\"precio\":"              + rs.getDouble("precio"));
                out.print("}");
            }
        }

        // =========================
        // 2. BUSCADOR / FILTRO POR CATEGORÍA
        // =========================
        else {

            StringBuilder sql = new StringBuilder("SELECT * FROM juegos");
            boolean firstFilter = true;

            if(categoriaId != null && !categoriaId.trim().isEmpty()) {
                sql.append(" WHERE id IN (SELECT juego_id FROM juego_categoria WHERE categoria_id=?)");
                firstFilter = false;
            }

            if(q != null && !q.trim().isEmpty()) {
                if(firstFilter) {
                    sql.append(" WHERE titulo LIKE ?");
                } else {
                    sql.append(" AND titulo LIKE ?");
                }
            }

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
                if(!first) json.append(",");

                String desc  = rs.getString("descripcion")       != null ? rs.getString("descripcion").replace("\"","'")  : "";
                String slug  = rs.getString("slug")              != null ? rs.getString("slug")                           : "";
                String img   = rs.getString("imagen_url")        != null ? rs.getString("imagen_url")                    : "";
                String vid   = rs.getString("video_url")         != null ? rs.getString("video_url")                     : "";
                String fecha = rs.getString("fecha_lanzamiento") != null ? rs.getString("fecha_lanzamiento")             : "";

                json.append("{")
                    .append("\"id\":").append(rs.getInt("id")).append(",")
                    .append("\"titulo\":\"").append(rs.getString("titulo")).append("\",")
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
    out.print("{\"error\":\""+e.getMessage()+"\"}");
}
%>