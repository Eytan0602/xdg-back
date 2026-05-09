<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String metodo = request.getMethod();

try {

    if("GET".equalsIgnoreCase(metodo)) {

        String gameParam = request.getParameter("juego_id");
        if(gameParam == null) { out.print("{\"error\":\"missing juego_id\"}"); return; }

        int juego_id = Integer.parseInt(gameParam);
        String sql = "SELECT c.*, u.usuario FROM comentarios c JOIN usuarios u ON c.usuario_id = u.id WHERE c.juego_id=? ORDER BY c.fecha DESC";
        PreparedStatement ps = con.prepareStatement(sql);
        ps.setInt(1, juego_id);
        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;
        while(rs.next()) {
            if(!first) json.append(",");
            String comentario = rs.getString("comentario").replace("\"","'");
            json.append("{")
                .append("\"id\":\"").append(rs.getString("id")).append("\",")
                .append("\"usuario\":\"").append(rs.getString("usuario")).append("\",")
                .append("\"comentario\":\"").append(comentario).append("\",")
                .append("\"likes\":").append(rs.getInt("likes")).append(",")
                .append("\"fecha\":\"").append(rs.getString("fecha")).append("\"")
                .append("}");
            first = false;
        }
        json.append("]");
        out.print(json.toString());

    } else if("POST".equalsIgnoreCase(metodo)) {

        String texto = param(request, jsonBody, "comentario");
        String user = param(request, jsonBody, "user_id");
        String gameParam = param(request, jsonBody, "juego_id");

        if(texto == null || user == null || gameParam == null) { out.print("{\"error\":\"missing fields\"}"); return; }

        int juego_id = Integer.parseInt(gameParam);
        String sql = "INSERT INTO comentarios(usuario_id,juego_id,comentario) VALUES(?,?,?)";
        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, user);
        ps.setInt(2, juego_id);
        ps.setString(3, texto);
        ps.executeUpdate();
        out.print("{\"success\":true}");

    } else if("PUT".equalsIgnoreCase(metodo)) {

        String comentarioId = param(request, jsonBody, "comentario_id");
        if(comentarioId == null) { out.print("{\"error\":\"missing comentario_id\"}"); return; }

        String sql = "UPDATE comentarios SET likes = likes + 1 WHERE id = ?";
        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, comentarioId);
        int r = ps.executeUpdate();
        out.print("{\"success\":" + (r > 0) + "}");

    }

} catch(Exception e) {
    out.print("{\"error\":\"" + e.getMessage().replace("\"", "") + "\"}");
}
%>