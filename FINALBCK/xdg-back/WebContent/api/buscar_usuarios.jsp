<%@ page import="java.sql.*" %>
<%@ page contentType="application/json; charset=UTF-8" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/db.jsp" %>

<%
// Requiere sesión iniciada (cualquier usuario logueado, no solo admin)
if (session.getAttribute("user_id") == null) {
    response.setStatus(401);
    out.print("{\"error\":\"No autorizado\"}");
    return;
}

String usuario = request.getParameter("usuario");

if (usuario == null || usuario.trim().isEmpty()) {
    out.print("[]");
    return;
}
usuario = usuario.trim();

try {

    // Busca coincidencias que empiecen con lo escrito (excluye eliminados)
    String sql = "SELECT id, nombre, usuario FROM usuarios " +
                 "WHERE usuario ILIKE ? " +
                 "AND (eliminado IS NULL OR eliminado = FALSE) " +
                 "ORDER BY usuario ASC LIMIT 5";

    PreparedStatement ps = con.prepareStatement(sql);
    ps.setString(1, "%" + usuario + "%");
    ResultSet rs = ps.executeQuery();

    StringBuilder json = new StringBuilder("[");
    boolean first = true;
    while (rs.next()) {
        if (!first) json.append(",");
        first = false;
        json.append("{")
            .append("\"id\":\"").append(esc(rs.getString("id"))).append("\",")
            .append("\"nombre\":\"").append(esc(rs.getString("nombre"))).append("\",")
            .append("\"usuario\":\"").append(esc(rs.getString("usuario"))).append("\"")
            .append("}");
    }
    json.append("]");
    rs.close(); ps.close();
    out.print(json.toString());

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
%>
<%@ include file="../includes/db_close.jsp" %>
