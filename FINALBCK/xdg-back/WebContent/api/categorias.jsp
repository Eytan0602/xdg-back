<%@ page import="java.sql.*, java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>
<%
response.setHeader("Access-Control-Allow-Origin", "http://localhost:4321");
response.setHeader("Access-Control-Allow-Credentials", "true");
response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
response.setHeader("Access-Control-Allow-Headers", "Content-Type");
if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
    response.setStatus(200);
    return;
}
%>
<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String method = request.getMethod();

try {

    if ("GET".equals(method)) {
        PreparedStatement psGet = con.prepareStatement("SELECT * FROM categorias");
        ResultSet rsGet = psGet.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;

        while (rsGet.next()) {
            if (!first) json.append(",");
            json.append("{")
                .append("\"id\":").append(rsGet.getInt("id")).append(",")
                .append("\"nombre\":\"").append(rsGet.getString("nombre")).append("\"")
                .append("}");
            first = false;
        }

        json.append("]");
        out.print(json.toString());
    }

    else if ("POST".equals(method)) {
        String nombre = param(request, jsonBody, "nombre");

        if (nombre == null || nombre.trim().isEmpty()) {
            out.print("{\"error\":\"nombre required\"}");
            return;
        }

        PreparedStatement psPost = con.prepareStatement("INSERT INTO categorias(nombre) VALUES(?)");
        psPost.setString(1, nombre);
        int rPost = psPost.executeUpdate();

        out.print("{\"success\":" + (rPost > 0) + "}");
    }

    else if ("PUT".equals(method)) {
        String id = param(request, jsonBody, "id");
        String nombre = param(request, jsonBody, "nombre");

        if (id == null || nombre == null) {
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        PreparedStatement psPut = con.prepareStatement("UPDATE categorias SET nombre=? WHERE id=?");
        psPut.setString(1, nombre);
        psPut.setInt(2, Integer.parseInt(id));
        int rPut = psPut.executeUpdate();

        out.print("{\"updated\":" + (rPut > 0) + "}");
    }

    else if ("DELETE".equals(method)) {
        String id = param(request, jsonBody, "id");

        if (id == null) {
            out.print("{\"error\":\"missing id\"}");
            return;
        }

        PreparedStatement psDel = con.prepareStatement("DELETE FROM categorias WHERE id=?");
        psDel.setInt(1, Integer.parseInt(id));
        int rDel = psDel.executeUpdate();

        out.print("{\"deleted\":" + (rDel > 0) + "}");
    }

} catch (Exception e) {
    out.print("{\"error\":\"" + e.getMessage().replace("\"", "") + "\"}");
}
%>