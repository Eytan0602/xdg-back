<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%!
public static String escapeJson(String s) {
  if (s == null) return "";
  StringBuilder sb = new StringBuilder();
  for (int i = 0; i < s.length(); i++) {
    char c = s.charAt(i);
    switch (c) {
      case '"': sb.append("\\\""); break;
      case '\\': sb.append("\\\\"); break;
      case '\b': sb.append("\\b"); break;
      case '\f': sb.append("\\f"); break;
      case '\n': sb.append("\\n"); break;
      case '\r': sb.append("\\r"); break;
      case '\t': sb.append("\\t"); break;
      default:
        if (c < 0x20) {
          sb.append(String.format("\\u%04x", (int)c));
        } else {
          sb.append(c);
        }
    }
  }
  return sb.toString();
}
%>

<%
Map<String,String> jsonBody = parseJsonBody(request);
try {
    String user_id = param(request, jsonBody, "user_id");
    if (user_id == null || user_id.trim().isEmpty()) {
        out.print("[]");
        return;
    }

    // Query new gifts received by user
    String sql = "SELECT v.id as venta_id, " +
                 "c.usuario as comprador_usuario, c.nombre as comprador_nombre, " +
                 "j.titulo as juego_titulo " +
                 "FROM ventas v " +
                 "INNER JOIN venta_detalle vd ON vd.venta_id = v.id " +
                 "INNER JOIN juegos j ON j.id = vd.juego_id " +
                 "INNER JOIN usuarios c ON v.relacionado_usuario_id = c.id " +
                 "WHERE v.usuario_id=? " +
                 "AND v.es_regalo = TRUE " +
                 "AND v.rol_regalo = 'recibido' " +
                 "AND (v.notificado IS NULL OR v.notificado = FALSE)";

    PreparedStatement ps = con.prepareStatement(sql);
    ps.setString(1, user_id);
    ResultSet rs = ps.executeQuery();

    List<String> list = new ArrayList<String>();
    List<String> ventasToUpdate = new ArrayList<String>();

    while (rs.next()) {
        String ventaId = rs.getString("venta_id");
        String compUsuario = rs.getString("comprador_usuario");
        String compNombre = rs.getString("comprador_nombre");
        String juegoTitulo = rs.getString("juego_titulo");

        ventasToUpdate.add(ventaId);

        String jsonItem = "{" +
            "\"venta_id\":\"" + escapeJson(ventaId) + "\"," +
            "\"comprador_usuario\":\"" + escapeJson(compUsuario) + "\"," +
            "\"comprador_nombre\":\"" + escapeJson(compNombre) + "\"," +
            "\"juego_titulo\":\"" + escapeJson(juegoTitulo) + "\"" +
            "}";
        list.add(jsonItem);
    }
    rs.close();
    ps.close();

    // Mark as notified so they don't see it again
    if (!ventasToUpdate.isEmpty()) {
        con.setAutoCommit(false);
        PreparedStatement updatePs = con.prepareStatement(
            "UPDATE ventas SET notificado = TRUE WHERE id = ?"
        );
        for (String vid : ventasToUpdate) {
            updatePs.setString(1, vid);
            updatePs.executeUpdate();
        }
        updatePs.close();
        con.commit();
    }

    out.print("[" + String.join(",", list) + "]");

} catch (Exception e) {
    out.print("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>
