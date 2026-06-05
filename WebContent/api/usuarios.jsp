<%@ page import="java.sql.*" %>
<%@ page contentType="application/json; charset=UTF-8" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/db.jsp" %>
<%

String method = request.getMethod().toUpperCase();

StringBuilder sb = new StringBuilder();
try {
    java.io.BufferedReader reader = request.getReader();
    String line;
    while ((line = reader.readLine()) != null) sb.append(line);
} catch (Exception ignored) {}
String body = sb.toString().trim();

String methodOverride = request.getParameter("_method");
if (methodOverride != null && !methodOverride.isEmpty()) method = methodOverride.toUpperCase();

try {

    if (method.equals("GET")) {

        String sql = "SELECT u.id, u.nombre, u.usuario, u.correo, u.fecha_registro, " +
                     "r.id AS rol_id, r.nombre AS rol " +
                     "FROM usuarios u " +
                     "JOIN roles r ON u.rol_id = r.id " +
                     "WHERE r.nombre IN ('ADMIN','SOPORTE') " +
                     "ORDER BY u.fecha_registro DESC";

        PreparedStatement ps = con.prepareStatement(sql);
        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;
        while (rs.next()) {
            if (!first) json.append(",");
            first = false;
            json.append("{")
                .append("\"id\":\"")            .append(esc(rs.getString("id")))             .append("\",")
                .append("\"nombre\":\"")        .append(esc(rs.getString("nombre")))         .append("\",")
                .append("\"usuario\":\"")       .append(esc(rs.getString("usuario")))        .append("\",")
                .append("\"correo\":\"")        .append(esc(rs.getString("correo")))         .append("\",")
                .append("\"fecha_registro\":\"").append(esc(rs.getString("fecha_registro"))).append("\",")
                .append("\"rol_id\":")          .append(rs.getInt("rol_id"))                 .append(",")
                .append("\"rol\":\"")           .append(esc(rs.getString("rol")))            .append("\"")
                .append("}");
        }
        json.append("]");
        rs.close(); ps.close();
        out.print(json.toString());

    } else if (method.equals("POST")) {

        String nombre     = jsonGet(body, "nombre");
        String usuario    = jsonGet(body, "usuario");
        String correo     = jsonGet(body, "correo");
        String contrasena = jsonGet(body, "contrasena");
        String rolIdStr   = jsonGetNum(body, "rol_id");

        if (nombre == null || usuario == null || correo == null || contrasena == null || rolIdStr == null) {
            out.print("{\"error\":\"Faltan campos obligatorios: nombre, usuario, correo, contrasena, rol_id\"}");
            return;
        }

        int rolId = Integer.parseInt(rolIdStr);

        PreparedStatement rolCheck = con.prepareStatement("SELECT nombre FROM roles WHERE id = ?");
        rolCheck.setInt(1, rolId);
        ResultSet rolRs = rolCheck.executeQuery();
        if (!rolRs.next()) { out.print("{\"error\":\"Rol no encontrado\"}"); return; }
        String rolNombre = rolRs.getString("nombre");
        rolRs.close(); rolCheck.close();

        if (!rolNombre.equals("ADMIN") && !rolNombre.equals("SOPORTE")) {
            out.print("{\"error\":\"Solo se permiten usuarios con rol ADMIN o SOPORTE\"}");
            return;
        }

        PreparedStatement ps = con.prepareStatement(
            "INSERT INTO usuarios (nombre, usuario, correo, contrasena, rol_id) " +
            "VALUES (?, ?, ?, ?, ?) RETURNING id, nombre, usuario, correo, fecha_registro");
        ps.setString(1, nombre);
        ps.setString(2, usuario);
        ps.setString(3, correo);
        ps.setString(4, contrasena);
        ps.setInt   (5, rolId);
        ResultSet rs = ps.executeQuery();

        if (rs.next()) {
            out.print("{\"success\":true," +
                "\"id\":\""             + esc(rs.getString("id"))             + "\"," +
                "\"nombre\":\""         + esc(rs.getString("nombre"))         + "\"," +
                "\"usuario\":\""        + esc(rs.getString("usuario"))        + "\"," +
                "\"correo\":\""         + esc(rs.getString("correo"))         + "\"," +
                "\"fecha_registro\":\"" + esc(rs.getString("fecha_registro")) + "\"," +
                "\"rol_id\":"           + rolId                               + "," +
                "\"rol\":\""            + esc(rolNombre)                      + "\"}");
        }
        rs.close(); ps.close();

    } else if (method.equals("PUT")) {

        String userId     = jsonGet(body, "id");
        String nombre     = jsonGet(body, "nombre");
        String usuario    = jsonGet(body, "usuario");
        String correo     = jsonGet(body, "correo");
        String contrasena = jsonGet(body, "contrasena");
        String rolIdStr   = jsonGetNum(body, "rol_id");

        if (userId == null || nombre == null || usuario == null || correo == null || rolIdStr == null) {
            out.print("{\"error\":\"Faltan campos: id, nombre, usuario, correo, rol_id\"}");
            return;
        }

        int rolId = Integer.parseInt(rolIdStr);

        PreparedStatement rolCheck = con.prepareStatement("SELECT nombre FROM roles WHERE id = ?");
        rolCheck.setInt(1, rolId);
        ResultSet rolRs = rolCheck.executeQuery();
        if (!rolRs.next()) { out.print("{\"error\":\"Rol no encontrado\"}"); return; }
        String rolNombre = rolRs.getString("nombre");
        rolRs.close(); rolCheck.close();

        if (!rolNombre.equals("ADMIN") && !rolNombre.equals("SOPORTE")) {
            out.print("{\"error\":\"Solo se permiten usuarios con rol ADMIN o SOPORTE\"}");
            return;
        }

        boolean cambiaPass = contrasena != null && !contrasena.isEmpty();
        String updateSql = cambiaPass
            ? "UPDATE usuarios SET nombre=?, usuario=?, correo=?, contrasena=?, rol_id=? WHERE id=?"
            : "UPDATE usuarios SET nombre=?, usuario=?, correo=?, rol_id=? WHERE id=?";

        PreparedStatement ps = con.prepareStatement(updateSql);
        ps.setString(1, nombre);
        ps.setString(2, usuario);
        ps.setString(3, correo);
        if (cambiaPass) {
            ps.setString(4, contrasena);
            ps.setInt   (5, rolId);
            ps.setString(6, userId);
        } else {
            ps.setInt   (4, rolId);
            ps.setString(5, userId);
        }

        int filas = ps.executeUpdate();
        ps.close();
        out.print("{\"success\":" + (filas > 0) + ",\"filas_afectadas\":" + filas + "}");

    } else if (method.equals("DELETE")) {

        String userId = request.getParameter("id");
        if (userId == null || userId.isEmpty()) userId = jsonGet(body, "id");
        if (userId == null || userId.isEmpty()) {
            out.print("{\"error\":\"Se requiere el id del usuario\"}");
            return;
        }

        PreparedStatement checkPs = con.prepareStatement(
            "SELECT u.id FROM usuarios u JOIN roles r ON u.rol_id = r.id " +
            "WHERE u.id = ? AND r.nombre IN ('ADMIN','SOPORTE')");
        checkPs.setString(1, userId);
        ResultSet checkRs = checkPs.executeQuery();
        if (!checkRs.next()) {
            out.print("{\"error\":\"Usuario no encontrado o no tiene rol permitido\"}");
            checkRs.close(); checkPs.close(); return;
        }
        checkRs.close(); checkPs.close();

        PreparedStatement ps = con.prepareStatement("DELETE FROM usuarios WHERE id = ?");
        ps.setString(1, userId);
        int filas = ps.executeUpdate();
        ps.close();
        out.print("{\"success\":" + (filas > 0) + ",\"filas_afectadas\":" + filas + "}");

    } else {
        response.setStatus(405);
        out.print("{\"error\":\"Metodo no permitido\"}");
    }

} catch (Exception e) {
    String msg = e.getMessage() != null
        ? e.getMessage().replace("\"", "'").replace("\n", " ")
        : "Error desconocido";
    out.print("{\"error\":\"" + msg + "\"}");
}
%>
<%!
private String esc(String s) {
    if (s == null) return "";
    return s.replace("\\", "\\\\").replace("\"", "\\\"")
            .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t");
}
private String jsonGet(String json, String key) {
    if (json == null || json.isEmpty()) return null;
    String pattern = "\"" + key + "\"";
    int ki = json.indexOf(pattern);
    if (ki < 0) return null;
    int colon = json.indexOf(":", ki + pattern.length());
    if (colon < 0) return null;
    int start = json.indexOf("\"", colon + 1);
    if (start < 0) return null;
    int end = start + 1;
    while (end < json.length()) {
        if (json.charAt(end) == '\\') { end += 2; continue; }
        if (json.charAt(end) == '"')  break;
        end++;
    }
    String val = json.substring(start + 1, end);
    return val.isEmpty() ? null : val;
}
private String jsonGetNum(String json, String key) {
    if (json == null || json.isEmpty()) return null;
    String pattern = "\"" + key + "\"";
    int ki = json.indexOf(pattern);
    if (ki < 0) return null;
    int colon = json.indexOf(":", ki + pattern.length());
    if (colon < 0) return null;
    int start = colon + 1;
    while (start < json.length() && json.charAt(start) == ' ') start++;
    int end = start;
    while (end < json.length() && (Character.isDigit(json.charAt(end)) || json.charAt(end) == '-')) end++;
    if (start == end) return null;
    return json.substring(start, end);
}
%>
