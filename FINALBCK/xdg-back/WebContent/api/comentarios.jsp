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

        if(gameParam == null) {
            out.print("{\"error\":\"missing juego_id\"}");
            return;
        }

        int juego_id = Integer.parseInt(gameParam);

        String sql =
        "SELECT c.*, u.usuario " +
        "FROM comentarios c " +
        "JOIN usuarios u ON c.usuario_id = u.id " +
        "WHERE c.juego_id=? " +
        "ORDER BY c.fecha DESC";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setInt(1, juego_id);

        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;

        while(rs.next()) {

            if(!first) json.append(",");

            String comentario =
            rs.getString("comentario")
            .replace("\"","'");

            int estrellas = 5;
            try { estrellas = rs.getInt("estrellas"); } catch(Exception ignored) {}

            json.append("{")
                .append("\"id\":\"").append(rs.getString("id")).append("\",")
                .append("\"usuario\":\"").append(rs.getString("usuario")).append("\",")
                .append("\"comentario\":\"").append(comentario).append("\",")
                .append("\"likes\":").append(rs.getInt("likes")).append(",")
                .append("\"estrellas\":").append(estrellas).append(",")
                .append("\"fecha\":\"").append(rs.getString("fecha")).append("\"")
                .append("}");

            first = false;
        }

        json.append("]");

        out.print(json.toString());
    }

  
    else if("POST".equalsIgnoreCase(metodo)) {

        String texto = param(request, jsonBody, "comentario");
        String user = param(request, jsonBody, "user_id");
        String gameParam = param(request, jsonBody, "juego_id");
        String estrellasParam = param(request, jsonBody, "estrellas");

        if(texto == null || user == null || gameParam == null) {
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        int juego_id = Integer.parseInt(gameParam);
        int estrellas = (estrellasParam != null) ? Integer.parseInt(estrellasParam) : 5;

        try {
            con.createStatement().execute("ALTER TABLE comentarios ADD COLUMN IF NOT EXISTS estrellas INT DEFAULT 5");
        } catch(Exception ignored) {}

        String sql =
        "INSERT INTO comentarios(usuario_id,juego_id,comentario,estrellas) " +
        "VALUES(?,?,?,?)";

        PreparedStatement ps = con.prepareStatement(sql);

        ps.setString(1,user);
        ps.setInt(2,juego_id);
        ps.setString(3,texto);
        ps.setInt(4,estrellas);

        ps.executeUpdate();

        out.print("{\"success\":true}");
    }

} catch(Exception e) {

    out.print("{\"error\":\""+e.getMessage().replace("\"","")+"\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>
