<%@ page import="java.sql.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);

try {

    String metodo = request.getMethod();

    if("GET".equalsIgnoreCase(metodo)) {

        String user = param(request, jsonBody, "user_id");

        if(user == null || user.trim().isEmpty()) {
            out.print("{\"error\":\"missing user_id\"}");
            return;
        }

        String sql =
            "SELECT w.id, j.id AS juego_id, j.titulo, j.precio, j.imagen_url " +
            "FROM wishlist w " +
            "INNER JOIN juegos j ON w.juego_id = j.id " +
            "WHERE w.usuario_id=?";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, user);

        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;

        while(rs.next()) {

            if(!first) json.append(",");

            json.append("{")
                .append("\"wishlist_id\":").append(rs.getInt("id")).append(",")
                .append("\"juego_id\":").append(rs.getInt("juego_id")).append(",")
                .append("\"titulo\":\"").append(rs.getString("titulo")).append("\",")
                .append("\"precio\":").append(rs.getDouble("precio")).append(",")
                .append("\"imagen_url\":\"")
                .append(rs.getString("imagen_url") != null ? rs.getString("imagen_url") : "")
                .append("\"")
                .append("}");

            first = false;
        }

        json.append("]");

        out.print(json.toString());
    }

    else if("POST".equalsIgnoreCase(metodo)) {

        String user = param(request, jsonBody, "user_id");
        String gameParam = param(request, jsonBody, "juego_id");

        if(user == null || gameParam == null) {
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        int juego_id = Integer.parseInt(gameParam);

        String sql =
            "INSERT INTO wishlist(usuario_id,juego_id) VALUES(?,?)";

        PreparedStatement ps = con.prepareStatement(sql);

        ps.setString(1, user);
        ps.setInt(2, juego_id);

        ps.executeUpdate();

        out.print("{\"success\":true}");
    }

    else if("DELETE".equalsIgnoreCase(metodo)) {

        String id = param(request, jsonBody, "id");

        if(id == null || id.trim().isEmpty()) {
            out.print("{\"error\":\"missing id\"}");
            return;
        }

        String sql = "DELETE FROM wishlist WHERE id=?";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setInt(1, Integer.parseInt(id));

        int rows = ps.executeUpdate();

        if(rows > 0){
            out.print("{\"success\":true}");
        }else{
            out.print("{\"success\":false,\"message\":\"No encontrado\"}");
        }
    }

    else {
        response.setStatus(405);
        out.print("{\"error\":\"Method Not Allowed\"}");
    }

}
catch(java.sql.SQLIntegrityConstraintViolationException e){

    out.print("{\"success\":false,\"message\":\"already exists\"}");

}
catch(Exception e){

    out.print("{\"error\":\"" + e.getMessage().replace("\"","") + "\"}");

}
%>

<%@ include file="../includes/db_close.jsp" %>