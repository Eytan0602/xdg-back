<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" pageEncoding="UTF-8" %>
<% request.setCharacterEncoding("UTF-8"); %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String metodo = request.getMethod();

String role = (String) session.getAttribute("user_role");
boolean esAdmin = "admin".equals(role);

try {


    if("GET".equalsIgnoreCase(metodo)) {

        String expireSql =
            "UPDATE descuentos SET activo = FALSE " +
            "WHERE activo = TRUE AND fecha_fin < NOW()";
        con.prepareStatement(expireSql).executeUpdate();

        String restoreSql =
            "UPDATE juegos j " +
            "SET precio = d.precio_original " +
            "FROM descuentos d " +
            "WHERE d.juego_id = j.id " +
            "  AND d.activo = FALSE " +
            "  AND j.precio <> d.precio_original " +
            "  AND d.fecha_fin < NOW()";
        con.prepareStatement(restoreSql).executeUpdate();

        String juegoIdParam = request.getParameter("juego_id");

       StringBuilder sql = new StringBuilder(
    "SELECT d.*, j.titulo, j.imagen_url, j.descripcion, " +
    "ROUND(d.precio_original * (1 - d.porcentaje / 100.0), 2) AS precio_con_descuento, " +
    "ROUND(d.precio_original * (1 - d.porcentaje / 100.0), 2) AS precio_actual " +
    "FROM descuentos d " +
    "JOIN juegos j ON j.id = d.juego_id " +
    "WHERE d.activo = TRUE "
);
        if(juegoIdParam != null && !juegoIdParam.trim().isEmpty()) {
            sql.append("AND d.juego_id = ? ");
        }

        if(!esAdmin) {
            sql.append("AND d.fecha_fin > NOW() ");
        }

        sql.append("ORDER BY d.fecha_fin ASC");

        PreparedStatement ps = con.prepareStatement(sql.toString());
        if(juegoIdParam != null && !juegoIdParam.trim().isEmpty()) {
            ps.setInt(1, Integer.parseInt(juegoIdParam));
        }

        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;

        while(rs.next()) {
            if(!first) json.append(",");
            json.append("{")
    .append("\"id\":").append(rs.getInt("id")).append(",")
    .append("\"juego_id\":").append(rs.getInt("juego_id")).append(",")
    .append("\"titulo\":\"").append(rs.getString("titulo")).append("\",")
    .append("\"descripcion\":\"").append(rs.getString("descripcion") != null ? rs.getString("descripcion").replace("\"","'") : "").append("\",")  // ← nuevo
    .append("\"imagen_url\":\"").append(rs.getString("imagen_url") != null ? rs.getString("imagen_url") : "").append("\",")                       // ← nuevo
    .append("\"porcentaje\":").append(rs.getDouble("porcentaje")).append(",")
    .append("\"precio_original\":").append(rs.getDouble("precio_original")).append(",")
    .append("\"precio_actual\":").append(rs.getDouble("precio_actual")).append(",")
    .append("\"precio_con_descuento\":").append(rs.getDouble("precio_con_descuento")).append(",")
    .append("\"fecha_inicio\":\"").append(rs.getString("fecha_inicio")).append("\",")
    .append("\"fecha_fin\":\"").append(rs.getString("fecha_fin")).append("\",")
    .append("\"activo\":").append(rs.getBoolean("activo"))
    .append("}");
            first = false;
        }

        json.append("]");
        out.print(json.toString());
    }

   
    else if("POST".equalsIgnoreCase(metodo)) {

        if(!esAdmin) {
            out.print("{\"error\":\"unauthorized\"}");
            return;
        }

        String juegoIdParam  = param(request, jsonBody, "juego_id");
        String porcentajeParam = param(request, jsonBody, "porcentaje");
        String fechaFin      = param(request, jsonBody, "fecha_fin");

        if(juegoIdParam == null || porcentajeParam == null || fechaFin == null) {
            out.print("{\"error\":\"missing fields: juego_id, porcentaje, fecha_fin\"}");
            return;
        }

        int    juegoId    = Integer.parseInt(juegoIdParam);
        double porcentaje = Double.parseDouble(porcentajeParam);

        if(porcentaje <= 0 || porcentaje >= 100) {
            out.print("{\"error\":\"porcentaje debe estar entre 1 y 99\"}");
            return;
        }

        String getPriceSql = "SELECT precio FROM juegos WHERE id = ?";
        PreparedStatement getPricePs = con.prepareStatement(getPriceSql);
        getPricePs.setInt(1, juegoId);
        ResultSet priceRs = getPricePs.executeQuery();

        if(!priceRs.next()) {
            out.print("{\"error\":\"juego no encontrado\"}");
            return;
        }

        double precioOriginal = priceRs.getDouble("precio");

        String deactivateSql =
            "UPDATE descuentos SET activo = FALSE WHERE juego_id = ? AND activo = TRUE";
        PreparedStatement deactivatePs = con.prepareStatement(deactivateSql);
        deactivatePs.setInt(1, juegoId);
        deactivatePs.executeUpdate();

        double precioConDescuento = precioOriginal * (1 - porcentaje / 100.0);
        precioConDescuento = Math.round(precioConDescuento * 100.0) / 100.0;

        String insertSql =
            "INSERT INTO descuentos(juego_id, porcentaje, precio_original, fecha_inicio, fecha_fin, activo) " +
            "VALUES(?, ?, ?, NOW(), ?::TIMESTAMP, TRUE)";
        PreparedStatement insertPs = con.prepareStatement(insertSql);
        insertPs.setInt(1, juegoId);
        insertPs.setDouble(2, porcentaje);
        insertPs.setDouble(3, precioOriginal);
        insertPs.setString(4, fechaFin);
        insertPs.executeUpdate();

        String updatePriceSql = "UPDATE juegos SET precio = ? WHERE id = ?";
        PreparedStatement updatePs = con.prepareStatement(updatePriceSql);
        updatePs.setDouble(1, precioConDescuento);
        updatePs.setInt(2, juegoId);
        updatePs.executeUpdate();

        out.print("{");
        out.print("\"success\":true,");
        out.print("\"precio_original\":" + precioOriginal + ",");
        out.print("\"porcentaje\":" + porcentaje + ",");
        out.print("\"precio_actual\":" + precioConDescuento + ",");
    out.print("\"precio_con_descuento\":" + precioConDescuento + ",");
        out.print("\"fecha_fin\":\"" + fechaFin + "\",");
        out.print("\"activo\":true");
        out.print("}");
    }

    
    else if("DELETE".equalsIgnoreCase(metodo)) {

        if(!esAdmin) {
            out.print("{\"error\":\"unauthorized\"}");
            return;
        }

        String juegoIdParam = param(request, jsonBody, "juego_id");
        if(juegoIdParam == null) {
            out.print("{\"error\":\"missing juego_id\"}");
            return;
        }

        int juegoId = Integer.parseInt(juegoIdParam);

        String getOriginalSql =
            "SELECT precio_original FROM descuentos " +
            "WHERE juego_id = ? AND activo = TRUE";
        PreparedStatement getPs = con.prepareStatement(getOriginalSql);
        getPs.setInt(1, juegoId);
        ResultSet getRs = getPs.executeQuery();

        if(!getRs.next()) {
            out.print("{\"error\":\"no hay descuento activo para ese juego\"}");
            return;
        }

        double precioOriginal = getRs.getDouble("precio_original");

        String deactivateSql =
            "UPDATE descuentos SET activo = FALSE WHERE juego_id = ? AND activo = TRUE";
        PreparedStatement deactivatePs = con.prepareStatement(deactivateSql);
        deactivatePs.setInt(1, juegoId);
        deactivatePs.executeUpdate();

        String restorePrice = "UPDATE juegos SET precio = ? WHERE id = ?";
        PreparedStatement restorePs = con.prepareStatement(restorePrice);
        restorePs.setDouble(1, precioOriginal);
        restorePs.setInt(2, juegoId);
        restorePs.executeUpdate();

        out.print("{\"success\":true,\"precio_restaurado\":" + precioOriginal + "}");
    }

    else {
        out.print("{\"error\":\"invalid method\"}");
    }

} catch(Exception e) {
    out.print("{\"error\":\"" + e.getMessage().replace("\"","") + "\"}");
}
%>