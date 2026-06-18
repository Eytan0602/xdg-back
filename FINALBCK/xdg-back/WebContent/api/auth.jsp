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

        String checkAdminSql = "SELECT u.id FROM usuarios u JOIN roles r ON u.rol_id = r.id " +
                               "WHERE u.correo = ? AND r.nombre IN ('ADMIN','SOPORTE')";
        PreparedStatement checkPs = con.prepareStatement(checkAdminSql);
        checkPs.setString(1, correo);
        ResultSet checkRs = checkPs.executeQuery();
        if(checkRs.next()){
            out.print("{\"success\":false,\"message\":\"Correo no permitido para registro\"}");
            checkRs.close(); checkPs.close();
            return;
        }
        checkRs.close(); checkPs.close();

        String hash = BCrypt.hashpw(contrasena, BCrypt.gensalt());

        String sql = "INSERT INTO usuarios(nombre, usuario, correo, contrasena, rol_id) " +
                     "VALUES(?,?,?,?, (SELECT id FROM roles WHERE nombre = 'CLIENTE'))";
        PreparedStatement ps = con.prepareStatement(sql, new String[]{"id"});
        ps.setString(1, nombre);
        ps.setString(2, usuario);
        ps.setString(3, correo);
        ps.setString(4, hash);

        int r = ps.executeUpdate();
        String newId = "";
        ResultSet generatedKeys = ps.getGeneratedKeys();
        if(generatedKeys.next()) newId = generatedKeys.getString(1);

        out.print("{\"success\":" + (r > 0) + ",\"id\":\"" + newId + "\"}");
    }

    else if("POST".equals(method) && "login".equals(action)) {

        String correo     = param(request, jsonBody, "correo");
        String contrasena = param(request, jsonBody, "contrasena");

        if(correo == null || contrasena == null){
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        String sqlAdmin = "SELECT u.*, r.nombre AS rol_nombre " +
                          "FROM usuarios u " +
                          "JOIN roles r ON u.rol_id = r.id " +
                          "WHERE u.correo = ? AND r.nombre IN ('ADMIN','SOPORTE') " +
                          "AND (u.eliminado IS NULL OR u.eliminado = FALSE)";
        PreparedStatement psAdmin = con.prepareStatement(sqlAdmin);
        psAdmin.setString(1, correo);
        ResultSet rsAdmin = psAdmin.executeQuery();

        if(rsAdmin.next()) {
            String hash = rsAdmin.getString("contrasena");
            if(BCrypt.checkpw(contrasena, hash)) {
                String adminNombre = rsAdmin.getString("nombre");
                String adminId     = rsAdmin.getString("id");
                String subRol      = rsAdmin.getString("rol_nombre");
                session.setAttribute("user_id",       adminId);
                session.setAttribute("user_name",     adminNombre);
                session.setAttribute("user_role",     "admin");
                session.setAttribute("user_sub_role", subRol);

                // Actualizar ultimo_acceso
                PreparedStatement psAcceso = con.prepareStatement(
                    "UPDATE usuarios SET ultimo_acceso = NOW() WHERE id = ?");
                psAcceso.setString(1, adminId);
                psAcceso.executeUpdate();
                psAcceso.close();

                out.print("{");
                out.print("\"success\":true,");
                out.print("\"id\":\"" + adminId + "\",");
                out.print("\"nombre\":\"" + adminNombre + "\",");
                out.print("\"role\":\"admin\",");
                out.print("\"sub_role\":\"" + subRol + "\"");
                out.print("}");
            } else {
                out.print("{\"success\":false,\"message\":\"Contraseña incorrecta\"}");
            }
            rsAdmin.close(); psAdmin.close();
            return;
        }
        rsAdmin.close(); psAdmin.close();

        String sqlUser = "SELECT u.* FROM usuarios u " +
                         "JOIN roles r ON u.rol_id = r.id " +
                         "WHERE u.correo = ? AND r.nombre = 'CLIENTE' " +
                         "AND (u.eliminado IS NULL OR u.eliminado = FALSE)";
        PreparedStatement psUser = con.prepareStatement(sqlUser);
        psUser.setString(1, correo);
        ResultSet rsUser = psUser.executeQuery();

        if(rsUser.next()) {
            String hash = rsUser.getString("contrasena");
            if(BCrypt.checkpw(contrasena, hash)) {
                String userId        = rsUser.getString("id");
                String nombreUsuario = rsUser.getString("nombre");
                session.setAttribute("user_id",   userId);
                session.setAttribute("user_name",  nombreUsuario);
                session.setAttribute("user_role",  "user");

                // Actualizar ultimo_acceso
                PreparedStatement psAcceso = con.prepareStatement(
                    "UPDATE usuarios SET ultimo_acceso = NOW() WHERE id = ?");
                psAcceso.setString(1, userId);
                psAcceso.executeUpdate();
                psAcceso.close();

                out.print("{");
                out.print("\"success\":true,");
                out.print("\"id\":\"" + userId + "\",");
                out.print("\"nombre\":\"" + nombreUsuario + "\",");
                out.print("\"role\":\"user\"");
                out.print("}");
            } else {
                out.print("{\"success\":false,\"message\":\"Contraseña incorrecta\"}");
            }
        } else {
            out.print("{\"success\":false,\"message\":\"Usuario no encontrado\"}");
        }
        rsUser.close(); psUser.close();
    }

    else if("POST".equals(method) && "logout".equals(action)) {
        session.invalidate();
        out.print("{\"success\":true}");
    }

    else if("POST".equals(method) && "updateInfo".equals(action)) {

        String userId = (String) session.getAttribute("user_id");
        if(userId == null) {
            out.print("{\"success\":false,\"message\":\"No autenticado\"}");
            return;
        }

        String nombre  = param(request, jsonBody, "nombre");
        String usuario = param(request, jsonBody, "usuario");
        String correo  = param(request, jsonBody, "correo");

        if(nombre == null || usuario == null || correo == null) {
            out.print("{\"success\":false,\"message\":\"Faltan campos\"}");
            return;
        }

        PreparedStatement checkPs = con.prepareStatement(
            "SELECT id FROM usuarios WHERE (correo = ? OR usuario = ?) AND id <> ?");
        checkPs.setString(1, correo);
        checkPs.setString(2, usuario);
        checkPs.setString(3, userId);
        ResultSet checkRs = checkPs.executeQuery();
        if(checkRs.next()) {
            out.print("{\"success\":false,\"message\":\"El correo o usuario ya está en uso\"}");
            checkRs.close(); checkPs.close();
            return;
        }
        checkRs.close(); checkPs.close();

        PreparedStatement ps = con.prepareStatement(
            "UPDATE usuarios SET nombre=?, usuario=?, correo=? WHERE id=?");
        ps.setString(1, nombre);
        ps.setString(2, usuario);
        ps.setString(3, correo);
        ps.setString(4, userId);
        int r = ps.executeUpdate();
        ps.close();

        if(r > 0) {
            session.setAttribute("user_name", nombre);
            out.print("{\"success\":true}");
        } else {
            out.print("{\"success\":false,\"message\":\"No se pudo actualizar la información\"}");
        }
    }

    else if("POST".equals(method) && "changePassword".equals(action)) {

        String userId = (String) session.getAttribute("user_id");
        if(userId == null) {
            out.print("{\"success\":false,\"message\":\"No autenticado\"}");
            return;
        }

        String currentPassword = param(request, jsonBody, "currentPassword");
        String newPassword     = param(request, jsonBody, "newPassword");

        if(currentPassword == null || newPassword == null) {
            out.print("{\"success\":false,\"message\":\"Faltan campos\"}");
            return;
        }

        PreparedStatement psGet = con.prepareStatement("SELECT contrasena FROM usuarios WHERE id = ?");
        psGet.setString(1, userId);
        ResultSet rsGet = psGet.executeQuery();
        if(!rsGet.next()) {
            out.print("{\"success\":false,\"message\":\"Usuario no encontrado\"}");
            rsGet.close(); psGet.close();
            return;
        }
        String hashActual = rsGet.getString("contrasena");
        rsGet.close(); psGet.close();

        if(!BCrypt.checkpw(currentPassword, hashActual)) {
            out.print("{\"success\":false,\"message\":\"La contraseña actual es incorrecta\"}");
            return;
        }

        String nuevoHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
        PreparedStatement ps = con.prepareStatement("UPDATE usuarios SET contrasena=? WHERE id=?");
        ps.setString(1, nuevoHash);
        ps.setString(2, userId);
        int r = ps.executeUpdate();
        ps.close();

        out.print("{\"success\":" + (r > 0) + "}");
    }

    else if("GET".equals(method) && "session".equals(action)) {
        String userId   = (String) session.getAttribute("user_id");
        String userName = (String) session.getAttribute("user_name");
        String userRole = (String) session.getAttribute("user_role");
        String subRole  = (String) session.getAttribute("user_sub_role");

        if(userId != null) {
            out.print("{");
            out.print("\"success\":true,");
            out.print("\"id\":\"" + userId + "\",");
            out.print("\"nombre\":\"" + userName + "\",");
            out.print("\"role\":\"" + userRole + "\"");
            if(subRole != null) {
                out.print(",\"sub_role\":\"" + subRole + "\"");
            }
            out.print("}");
        } else {
            out.print("{\"success\":false}");
        }
    }

    else {
        out.print("{\"error\":\"invalid action\"}");
    }

} catch(Exception e){
    String msg = e.getMessage() == null ? "error" : e.getMessage()
        .replace("\"", "")
        .replace("\n", " ")
        .replace("\r", " ")
        .replace("\t", " ");
    out.print("{\"error\":\"" + msg + "\"}");
}
%>