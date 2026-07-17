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
    String libraryParam = request.getParameter("library");
    boolean isLibrary = "true".equalsIgnoreCase(libraryParam);

    String sql =
    "SELECT v.id as venta_id, v.fecha, v.es_regalo, v.rol_regalo, v.tiene_boleta, v.usuario_id, v.relacionado_usuario_id, " +
    "ur.usuario as relacionado_usuario, ur.nombre as relacionado_nombre, ur.correo as relacionado_correo, " +
    "j.id as juego_id, j.titulo, j.imagen_url, vd.precio, vd.cantidad, j.precio as precio_original, j.fecha_lanzamiento " +
    "FROM ventas v " +
    "INNER JOIN venta_detalle vd ON vd.venta_id = v.id " +
    "INNER JOIN juegos j ON j.id = vd.juego_id " +
    "LEFT JOIN usuarios ur ON ur.id = v.relacionado_usuario_id " +
    "WHERE v.usuario_id=? " +
    "AND (CASE WHEN ? = TRUE " +
    "          THEN (v.es_regalo IS NULL OR v.es_regalo = FALSE OR v.rol_regalo = 'recibido') " +
    "          ELSE (v.es_regalo IS NULL OR v.es_regalo = FALSE OR v.rol_regalo = 'enviado') " +
    "     END) " +
    "ORDER BY v.fecha DESC";

    PreparedStatement ps = con.prepareStatement(sql);
    ps.setString(1, user_id);
    ps.setBoolean(2, isLibrary);

    ResultSet rs = ps.executeQuery();

    StringBuilder json = new StringBuilder("[");
    boolean first = true;

    while(rs.next()) {

        if(!first) json.append(",");

        boolean esRegalo = rs.getBoolean("es_regalo");
        String rolRegalo = rs.getString("rol_regalo");
        String relUsuario = rs.getString("relacionado_usuario");
        String relNombre = rs.getString("relacionado_nombre");
        String relCorreo = rs.getString("relacionado_correo");
        String userId = rs.getString("usuario_id");
        String relUserId = rs.getString("relacionado_usuario_id");

        String compradorId = userId;
        String destinatarioId = userId;
        String compradorUsuario = "";
        String compradorNombre = "";
        String destNombre = "";
        String destUsuario = "";
        String destCorreo = "";

        if (esRegalo) {
            if ("recibido".equals(rolRegalo)) {
                compradorId = relUserId;
                compradorUsuario = relUsuario;
                compradorNombre = relNombre;
            } else if ("enviado".equals(rolRegalo)) {
                destinatarioId = relUserId;
                destNombre = relNombre;
                destUsuario = relUsuario;
                destCorreo = relCorreo;
            }
        }

        json.append("{")
        .append("\"venta_id\":\"").append(rs.getString("venta_id")).append("\",")
        .append("\"fecha\":\"").append(rs.getString("fecha")).append("\",")
        .append("\"es_regalo\":").append(esRegalo).append(",")
        .append("\"comprador_id\":\"").append(escapeJson(compradorId)).append("\",")
        .append("\"usuario_id\":\"").append(escapeJson(destinatarioId)).append("\",")
        .append("\"comprador_usuario\":\"").append(escapeJson(compradorUsuario)).append("\",")
        .append("\"comprador_nombre\":\"").append(escapeJson(compradorNombre)).append("\",")
        .append("\"destinatario_nombre\":\"").append(escapeJson(destNombre)).append("\",")
        .append("\"destinatario_usuario\":\"").append(escapeJson(destUsuario)).append("\",")
        .append("\"destinatario_correo\":\"").append(escapeJson(destCorreo)).append("\",")
        .append("\"juego_id\":\"").append(rs.getString("juego_id")).append("\",")
        .append("\"titulo\":\"").append(escapeJson(rs.getString("titulo"))).append("\",")
        .append("\"imagen_url\":\"").append(escapeJson(rs.getString("imagen_url"))).append("\",")
        .append("\"precio\":").append(rs.getDouble("precio")).append(",")
        .append("\"cantidad\":").append(rs.getInt("cantidad")).append(",")
        .append("\"precio_original\":").append(rs.getDouble("precio_original")).append(",")
        .append("\"fecha_lanzamiento\":").append(rs.getDate("fecha_lanzamiento") != null ? "\"" + rs.getDate("fecha_lanzamiento").toString() + "\"" : "null")
        .append("}");

        first = false;
    }

    json.append("]");

    out.print(json.toString());

} catch(Exception e){
    out.print("{\"error\":\""+escapeJson(e.getMessage())+"\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>