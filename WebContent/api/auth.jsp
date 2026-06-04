<%@ page import="java.sql.*" %>
<%@ page import="org.mindrot.jbcrypt.BCrypt" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" pageEncoding="UTF-8" %>
<% request.setCharacterEncoding("UTF-8"); %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String method = request.getMethod();
String action = param(request, jsonBody, "action");

try {

    if("POST".equals(method) && "register".equals(action)) {

        String nombre     = param(request, jsonBody, "nombre");
        String usuario    = param(request, jsonBody, "usuario");
        String correo     = param(request, jsonBody, "correo");
        String contrasena = param(request, jsonBody, "contrasena");

        if(nombre == null || usuario == null || correo == null || contrasena == null){
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        if(correo.toLowerCase().endsWith("@admin.com")){
            out.print("{\"error\":\"correo no permitido para registro de usuario\"}");
            return;
        }

        String hash = BCrypt.hashpw(contrasena, BCrypt.gensalt());

        String randomPart = String.format("%08d", (int)(Math.random() * 100000000));
        String customId = "XD-" + randomPart;

        String sql = "INSERT INTO usuarios(id, nombre, usuario, correo, contrasena) VALUES(?,?,?,?,?)";
        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, customId);
        ps.setString(2, nombre);
        ps.setString(3, usuario);
        ps.setString(4, correo);
        ps.setString(5, hash);

        int r = ps.executeUpdate();
        out.print("{\"success\":" + (r > 0) + ",\"id\":\"" + customId + "\"}");
    }

    
    
    // =========================
    // LOGIN
    // =========================
    else if("POST".equals(method) && "login".equals(action)) {

        String correo     = param(request, jsonBody, "correo");
        String contrasena = param(request, jsonBody, "contrasena");

        if(correo == null || contrasena == null){
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        if(correo.toLowerCase().endsWith("@admin.com")) {

            String sql = "SELECT * FROM admins WHERE correo = ?";
            PreparedStatement ps = con.prepareStatement(sql);
            ps.setString(1, correo);
            ResultSet rs = ps.executeQuery();

            if(rs.next()) {
                String hash = rs.getString("contrasena");
                if(BCrypt.checkpw(contrasena, hash)) {
                    String adminNombre = rs.getString("nombre");
                    session.setAttribute("user_id",   "ADMIN-" + rs.getInt("id"));
                    session.setAttribute("user_name",  adminNombre);
                    session.setAttribute("user_role",  "admin");
                    out.print("{");
                    out.print("\"success\":true,");
                    out.print("\"id\":\"ADMIN-" + rs.getInt("id") + "\",");
                    out.print("\"nombre\":\"" + adminNombre + "\",");
                    out.print("\"role\":\"admin\"");
                    out.print("}");
                } else {
                    out.print("{\"success\":false,\"message\":\"wrong password\"}");
                }
            } else {
                out.print("{\"success\":false,\"message\":\"admin not found\"}");
            }
            return;
        }

        
        String sql = "SELECT * FROM usuarios WHERE correo = ?";
        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, correo);
        ResultSet rs = ps.executeQuery();

        if(rs.next()) {
            String hash = rs.getString("contrasena");
            if(BCrypt.checkpw(contrasena, hash)) {
                String userId        = rs.getString("id");
                String nombreUsuario = rs.getString("nombre");
                session.setAttribute("user_id",   userId);
                session.setAttribute("user_name",  nombreUsuario);
                session.setAttribute("user_role",  "user");
                out.print("{");
                out.print("\"success\":true,");
                out.print("\"id\":\"" + userId + "\",");
                out.print("\"nombre\":\"" + nombreUsuario + "\",");
                out.print("\"role\":\"user\"");
                out.print("}");
            } else {
                out.print("{\"success\":false,\"message\":\"wrong password\"}");
            }
        } else {
            out.print("{\"success\":false,\"message\":\"user not found\"}");
        }
    }

   
    else if("POST".equals(method) && "logout".equals(action)) {
        session.invalidate();
        out.print("{\"success\":true}");
    }

   else if("GET".equals(method) && "session".equals(action)) {

    String userId = (String) session.getAttribute("user_id");
    String userName = (String) session.getAttribute("user_name");
    String userRole = (String) session.getAttribute("user_role");

    if(userId != null) {

        out.print("{");
        out.print("\"success\":true,");
        out.print("\"id\":\"" + userId + "\",");
        out.print("\"nombre\":\"" + userName + "\",");
        out.print("\"role\":\"" + userRole + "\"");
        out.print("}");

    } else {

        out.print("{\"success\":false}");

    }
}
else {
    out.print("{\"error\":\"invalid action\"}");
}

} catch(Exception e){
    out.print("{\"error\":\"" + e.getMessage().replace("\"","") + "\"}");
}
%>
