<%@ page import="java.sql.*" %>
<%@ page import="org.mindrot.jbcrypt.BCrypt" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String method = request.getMethod();
String action = param(request, jsonBody, "action");

try {

    // =========================
    // REGISTER
    // =========================
    if("POST".equals(method) && "register".equals(action)) {

        String nombre = param(request, jsonBody, "nombre");
        String usuario = param(request, jsonBody, "usuario");
        String correo = param(request, jsonBody, "correo");
        String contrasena = param(request, jsonBody, "contrasena");

        if(nombre == null || usuario == null || correo == null || contrasena == null){
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        String hash = BCrypt.hashpw(contrasena, BCrypt.gensalt());

        String customId;
Statement stCount = con.createStatement();
ResultSet rsCount = stCount.executeQuery("SELECT COUNT(*) FROM usuarios");
rsCount.next();
int next = rsCount.getInt(1) + 1;
customId = String.format("XD-%08d", next);

        String sql =
        "INSERT INTO usuarios(id, nombre, usuario, correo, contrasena) VALUES(?,?,?,?,?)";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, customId);
        ps.setString(2, nombre);
        ps.setString(3, usuario);
        ps.setString(4, correo);
        ps.setString(5, hash);

        int r = ps.executeUpdate();
out.print("{\"success\":" + (r > 0) + "}");    }

    // =========================
    // LOGIN
    // =========================
    else if("POST".equals(method) && "login".equals(action)) {

        String correo = param(request, jsonBody, "correo");
        String contrasena = param(request, jsonBody, "contrasena");

        if(correo == null || contrasena == null){
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        String sql = "SELECT * FROM usuarios WHERE correo=?";
        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, correo);

        ResultSet rs = ps.executeQuery();

        if(rs.next()) {
            String hash = rs.getString("contrasena");
            if(BCrypt.checkpw(contrasena, hash)) {
                String userId = rs.getString("id");
                session.setAttribute("user_id", userId);
                session.setAttribute("user_name", rs.getString("nombre"));
                out.print("{");
                out.print("\"success\":true,");
                out.print("\"id\":\"" + userId + "\",");
                out.print("\"nombre\":\"" + rs.getString("nombre") + "\"");
                out.print("}");
            } else {
                out.print("{\"success\":false,\"message\":\"wrong password\"}");
            }
        } else {
            out.print("{\"success\":false,\"message\":\"user not found\"}");
        }
    }

    // =========================
    // LOGOUT
    // =========================
    else if("POST".equals(method) && "logout".equals(action)) {
        session.invalidate();
        out.print("{\"success\":true}");
    }

    else {
        out.print("{\"error\":\"invalid action\"}");
    }

} catch(Exception e){
    out.print("{\"error\":\"" + e.getMessage().replace("\"", "") + "\"}");
}
%>
