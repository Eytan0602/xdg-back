<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" pageEncoding="UTF-8" %>
<% request.setCharacterEncoding("UTF-8"); %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
String role = (String) session.getAttribute("user_role");
if(!"admin".equals(role)) {
    out.print("{\"error\":\"unauthorized\"}");
    return;
}

Map<String,String> jsonBody = parseJsonBody(request);
String metodo  = request.getMethod();
String seccion = request.getParameter("seccion");
if(seccion == null) seccion = param(request, jsonBody, "seccion");
if(seccion == null) seccion = "resumen";

try {

    if("GET".equalsIgnoreCase(metodo)) {

        if("resumen".equals(seccion)) {

            String totalSql =
                "SELECT COALESCE(SUM(vd.precio * vd.cantidad), 0) AS total_ganancias, " +
                "COUNT(DISTINCT v.id) AS total_ventas, " +
                "COUNT(DISTINCT v.usuario_id) AS clientes_unicos " +
                "FROM ventas v " +
                "JOIN venta_detalle vd ON vd.venta_id = v.id";

            ResultSet totalRs = con.prepareStatement(totalSql).executeQuery();
            double totalGanancias = 0;
            int totalVentas = 0;
            int clientesUnicos = 0;
            if(totalRs.next()) {
                totalGanancias = totalRs.getDouble("total_ganancias");
                totalVentas    = totalRs.getInt("total_ventas");
                clientesUnicos = totalRs.getInt("clientes_unicos");
            }

            String topSql =
                "SELECT j.titulo, SUM(vd.cantidad) AS unidades " +
                "FROM venta_detalle vd " +
                "JOIN juegos j ON j.id = vd.juego_id " +
                "GROUP BY j.titulo " +
                "ORDER BY unidades DESC LIMIT 1";

            ResultSet topRs = con.prepareStatement(topSql).executeQuery();
            String juegoTop = "N/A";
            int unidadesTop = 0;
            if(topRs.next()) {
                juegoTop    = topRs.getString("titulo");
                unidadesTop = topRs.getInt("unidades");
            }

            ResultSet usersRs = con.prepareStatement(
                "SELECT COUNT(*) AS total FROM usuarios"
            ).executeQuery();
            int totalUsuarios = 0;
            if(usersRs.next()) totalUsuarios = usersRs.getInt("total");

            out.print("{");
            out.print("\"total_ganancias\":"  + totalGanancias  + ",");
            out.print("\"total_ventas\":"     + totalVentas     + ",");
            out.print("\"clientes_unicos\":"  + clientesUnicos  + ",");
            out.print("\"total_usuarios\":"   + totalUsuarios   + ",");
            out.print("\"juego_top\":\""      + juegoTop.replace("\"","'") + "\",");
            out.print("\"juego_top_unidades\":" + unidadesTop);
            out.print("}");
        }

        else if("ventas".equals(seccion)) {

            String sql =
                "SELECT v.id AS venta_id, v.fecha, u.usuario, u.correo, " +
                "j.titulo, vd.precio, vd.cantidad, " +
                "(vd.precio * vd.cantidad) AS subtotal " +
                "FROM ventas v " +
                "JOIN usuarios u       ON u.id = v.usuario_id " +
                "JOIN venta_detalle vd ON vd.venta_id = v.id " +
                "JOIN juegos j         ON j.id = vd.juego_id " +
                "ORDER BY v.fecha DESC";

            ResultSet rs = con.prepareStatement(sql).executeQuery();
            StringBuilder json = new StringBuilder("[");
            boolean first = true;
            while(rs.next()) {
                if(!first) json.append(",");
                json.append("{")
                    .append("\"venta_id\":\"").append(rs.getString("venta_id")).append("\",")
                    .append("\"fecha\":\"").append(rs.getString("fecha")).append("\",")
                    .append("\"usuario\":\"").append(rs.getString("usuario")).append("\",")
                    .append("\"correo\":\"").append(rs.getString("correo")).append("\",")
                    .append("\"titulo\":\"").append(rs.getString("titulo").replace("\"","'")).append("\",")
                    .append("\"precio\":").append(rs.getDouble("precio")).append(",")
                    .append("\"cantidad\":").append(rs.getInt("cantidad")).append(",")
                    .append("\"subtotal\":").append(rs.getDouble("subtotal"))
                    .append("}");
                first = false;
            }
            json.append("]");
            out.print(json.toString());
        }

        else if("usuarios".equals(seccion)) {

            String sql =
                "SELECT u.id, u.nombre, u.usuario, u.correo, u.fecha_registro, " +
                "COALESCE(SUM(vd.precio * vd.cantidad), 0) AS total_gastado " +
                "FROM usuarios u " +
                "LEFT JOIN ventas v ON v.usuario_id = u.id " +
                "LEFT JOIN venta_detalle vd ON vd.venta_id = v.id " +
                "GROUP BY u.id, u.nombre, u.usuario, u.correo, u.fecha_registro " +
                "ORDER BY total_gastado DESC";

            ResultSet rs = con.prepareStatement(sql).executeQuery();
            StringBuilder json = new StringBuilder("[");
            boolean first = true;
            while(rs.next()) {
                if(!first) json.append(",");
                json.append("{")
                    .append("\"id\":\"").append(rs.getString("id")).append("\",")
                    .append("\"nombre\":\"").append(rs.getString("nombre")).append("\",")
                    .append("\"usuario\":\"").append(rs.getString("usuario")).append("\",")
                    .append("\"correo\":\"").append(rs.getString("correo")).append("\",")
                    .append("\"fecha_registro\":\"").append(rs.getString("fecha_registro")).append("\",")
                    .append("\"total_gastado\":").append(rs.getDouble("total_gastado"))
                    .append("}");
                first = false;
            }
            json.append("]");
            out.print(json.toString());
        }

        else {
            out.print("{\"error\":\"seccion invalida. Usa: resumen, ventas, usuarios\"}");
        }
    }

    
    else if("POST".equalsIgnoreCase(metodo)) {

        String titulo            = param(request, jsonBody, "titulo");
        String slug              = param(request, jsonBody, "slug");
        String descripcion       = param(request, jsonBody, "descripcion");
        String precioParam       = param(request, jsonBody, "precio");
        String imagen_url        = param(request, jsonBody, "imagen_url");
        String video_url         = param(request, jsonBody, "video_url");
        String fecha_lanzamiento = param(request, jsonBody, "fecha_lanzamiento");

        if(titulo == null || slug == null || precioParam == null) {
            out.print("{\"error\":\"missing fields: titulo, slug, precio\"}");
            return;
        }

        double precio = Double.parseDouble(precioParam);

        String sql =
            "INSERT INTO juegos(titulo, slug, descripcion, precio, imagen_url, video_url, fecha_lanzamiento) " +
            "VALUES(?,?,?,?,?,?,?::DATE)";

        PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
        ps.setString(1, titulo);
        ps.setString(2, slug);
        ps.setString(3, descripcion       != null ? descripcion       : "");
        ps.setDouble(4, precio);
        ps.setString(5, imagen_url        != null ? imagen_url        : "");
        ps.setString(6, video_url         != null ? video_url         : "");
        ps.setString(7, fecha_lanzamiento != null ? fecha_lanzamiento : "2024-01-01");
        ps.executeUpdate();

        ResultSet keys = ps.getGeneratedKeys();
        int newId = 0;
        if(keys.next()) newId = keys.getInt(1);

        out.print("{\"success\":true,\"id\":" + newId + "}");
    }

    
    else if("PUT".equalsIgnoreCase(metodo)) {

        String idParam    = param(request, jsonBody, "id");
        String titulo     = param(request, jsonBody, "titulo");
        String slug       = param(request, jsonBody, "slug");
        String desc       = param(request, jsonBody, "descripcion");
        String imagen     = param(request, jsonBody, "imagen_url");
        String video      = param(request, jsonBody, "video_url");
        String precioParam = param(request, jsonBody, "precio");

        if(idParam == null) {
            out.print("{\"error\":\"missing id\"}");
            return;
        }

        int id = Integer.parseInt(idParam);

        StringBuilder setClauses = new StringBuilder();
        if(titulo != null)      { if(setClauses.length()>0) setClauses.append(","); setClauses.append("titulo=?"); }
        if(slug != null)        { if(setClauses.length()>0) setClauses.append(","); setClauses.append("slug=?"); }
        if(desc != null)        { if(setClauses.length()>0) setClauses.append(","); setClauses.append("descripcion=?"); }
        if(imagen != null)      { if(setClauses.length()>0) setClauses.append(","); setClauses.append("imagen_url=?"); }
        if(video != null)       { if(setClauses.length()>0) setClauses.append(","); setClauses.append("video_url=?"); }
        if(precioParam != null) { if(setClauses.length()>0) setClauses.append(","); setClauses.append("precio=?"); }

        if(setClauses.length() == 0) {
            out.print("{\"error\":\"no fields to update\"}");
            return;
        }

        String sql = "UPDATE juegos SET " + setClauses.toString() + " WHERE id=?";
        PreparedStatement ps = con.prepareStatement(sql);

        int i = 1;
        if(titulo != null)      ps.setString(i++, titulo);
        if(slug != null)        ps.setString(i++, slug);
        if(desc != null)        ps.setString(i++, desc);
        if(imagen != null)      ps.setString(i++, imagen);
        if(video != null)       ps.setString(i++, video);
        if(precioParam != null) ps.setDouble(i++, Double.parseDouble(precioParam));
        ps.setInt(i, id);

        int r = ps.executeUpdate();
        out.print("{\"success\":" + (r > 0) + "}");
    }

    
    else if("DELETE".equalsIgnoreCase(metodo)) {

        String idParam = param(request, jsonBody, "id");
        if(idParam == null) {
            out.print("{\"error\":\"missing id\"}");
            return;
        }

        int id = Integer.parseInt(idParam);

        con.prepareStatement("DELETE FROM carrito_detalle WHERE juego_id = " + id).executeUpdate();
        con.prepareStatement("DELETE FROM wishlist WHERE juego_id = " + id).executeUpdate();
        con.prepareStatement("DELETE FROM comentarios WHERE juego_id = " + id).executeUpdate();
        con.prepareStatement("DELETE FROM juego_categoria WHERE juego_id = " + id).executeUpdate();
        con.prepareStatement("DELETE FROM descuentos WHERE juego_id = " + id).executeUpdate();

        PreparedStatement ps = con.prepareStatement("DELETE FROM juegos WHERE id = ?");
        ps.setInt(1, id);
        int r = ps.executeUpdate();

        out.print("{\"success\":" + (r > 0) + "}");
    }

    else {
        out.print("{\"error\":\"invalid method\"}");
    }

} catch(Exception e) {
    out.print("{\"error\":\"" + e.getMessage().replace("\"","") + "\"}");
}
%>
