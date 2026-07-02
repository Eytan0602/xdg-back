<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" pageEncoding="UTF-8" %>
<% request.setCharacterEncoding("UTF-8"); %>

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
String role = (String) session.getAttribute("user_role");
if(!"admin".equals(role)) {
    out.print("{\"error\":\"unauthorized\"}");
    return;
}

try {
    String subRole = (String) session.getAttribute("sub_role");
    if ("SOPORTE".equalsIgnoreCase(subRole)) {
        out.print("{\"error\":\"unauthorized\"}");
        return;
    }
    String sql = "SELECT j.id, j.titulo, j.imagen_url, " +
                 "SUM(vd.cantidad) AS total_vendido, " +
                 "SUM(vd.cantidad * vd.precio) AS ingresos_totales " +
                 "FROM venta_detalle vd " +
                 "JOIN juegos j ON vd.juego_id = j.id " +
                 "GROUP BY j.id, j.titulo, j.imagen_url " +
                 "ORDER BY total_vendido DESC " +
                 "LIMIT 10";

    PreparedStatement ps = con.prepareStatement(sql);
    ResultSet rs = ps.executeQuery();

    List<String> juegos = new ArrayList<String>();
    while (rs.next()) {
        String id = rs.getString("id");
        String titulo = rs.getString("titulo");
        String imagenUrl = rs.getString("imagen_url");
        int totalVendido = rs.getInt("total_vendido");
        double ingresosTotales = rs.getDouble("ingresos_totales");

        String item = "{" +
            "\"id\": " + id + ", " +
            "\"titulo\": \"" + escapeJson(titulo) + "\", " +
            "\"imagen_url\": \"" + escapeJson(imagenUrl) + "\", " +
            "\"total_vendido\": " + totalVendido + ", " +
            "\"ingresos_totales\": " + ingresosTotales + 
        "}";
        juegos.add(item);
    }
    
    out.print("[" + String.join(",", juegos) + "]");

} catch (Exception e) {
    out.print("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>
