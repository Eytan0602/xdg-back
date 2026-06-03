<%@ page import="java.sql.*, java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String method = request.getMethod();

try {

    
    if("GET".equals(method)) {

        String sql = "SELECT * FROM categorias";

        PreparedStatement ps = con.prepareStatement(sql);
        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;

        while(rs.next()) {

            if(!first) json.append(",");

            json.append("{")
            .append("\"id\":").append(rs.getInt("id")).append(",")
            .append("\"nombre\":\"").append(rs.getString("nombre")).append("\"")
            .append("}");

            first = false;
        }

        json.append("]");

        out.print(json.toString());
    }

    
    else if("POST".equals(method)) {

        String nombre = param(request, jsonBody, "nombre");

        if(nombre == null || nombre.trim().isEmpty()){
            out.print("{\"error\":\"nombre required\"}");
            return;
        }

        String sql = "INSERT INTO categorias(nombre) VALUES(?)";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, nombre);

        int r = ps.executeUpdate();

        out.print("{\"success\":"+(r>0)+"}");
    }

    
    else if("PUT".equals(method)) {

        String id = param(request, jsonBody, "id");
        String nombre = param(request, jsonBody, "nombre");

        if(id == null || nombre == null){
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        String sql = "UPDATE categorias SET nombre=? WHERE id=?";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, nombre);
        ps.setInt(2, Integer.parseInt(id));

        int r = ps.executeUpdate();

        out.print("{\"updated\":"+(r>0)+"}");
    }

    
    else if("DELETE".equals(method)) {

        String id = param(request, jsonBody, "id");

        String sql = "DELETE FROM categorias WHERE id=?";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setInt(1, Integer.parseInt(id));

        int r = ps.executeUpdate();

        out.print("{\"deleted\":"+(r>0)+"}");
    }

} catch(Exception e){
    out.print("{\"error\":\""+e.getMessage().replace("\"","")+"\"}");
}
%>