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
// Security role check
String role = (String) session.getAttribute("user_role");
if(!"admin".equals(role)) {
    out.print("{\"error\":\"unauthorized\"}");
    return;
}

try {
    // 1. Activity Summaries
    int totalUsuarios = 0;
    int activosHoy = 0;
    int activosSemana = 0;
    int activosMes = 0;
    int inactivos = 0;

    Statement stmt = con.createStatement();
    
    ResultSet rsTotal = stmt.executeQuery("SELECT COUNT(*) FROM usuarios WHERE COALESCE(eliminado, FALSE) = FALSE");
    if (rsTotal.next()) totalUsuarios = rsTotal.getInt(1);
    rsTotal.close();

    ResultSet rsHoy = stmt.executeQuery("SELECT COUNT(*) FROM usuarios WHERE COALESCE(eliminado, FALSE) = FALSE AND (ultimo_acceso >= NOW() - INTERVAL '1 day' OR (ultimo_acceso IS NULL AND fecha_registro >= NOW() - INTERVAL '1 day'))");
    if (rsHoy.next()) activosHoy = rsHoy.getInt(1);
    rsHoy.close();

    ResultSet rsSemana = stmt.executeQuery("SELECT COUNT(*) FROM usuarios WHERE COALESCE(eliminado, FALSE) = FALSE AND (ultimo_acceso >= NOW() - INTERVAL '7 days' OR (ultimo_acceso IS NULL AND fecha_registro >= NOW() - INTERVAL '7 days'))");
    if (rsSemana.next()) activosSemana = rsSemana.getInt(1);
    rsSemana.close();

    ResultSet rsMes = stmt.executeQuery("SELECT COUNT(*) FROM usuarios WHERE COALESCE(eliminado, FALSE) = FALSE AND (ultimo_acceso >= NOW() - INTERVAL '30 days' OR (ultimo_acceso IS NULL AND fecha_registro >= NOW() - INTERVAL '30 days'))");
    if (rsMes.next()) activosMes = rsMes.getInt(1);
    rsMes.close();

    ResultSet rsInactivos = stmt.executeQuery("SELECT COUNT(*) FROM usuarios WHERE COALESCE(eliminado, FALSE) = FALSE AND ((ultimo_acceso < NOW() - INTERVAL '30 days') OR (ultimo_acceso IS NULL AND fecha_registro < NOW() - INTERVAL '30 days'))");
    if (rsInactivos.next()) inactivos = rsInactivos.getInt(1);
    rsInactivos.close();

    // 2. Growth History (Registrations last 30 days)
    String growthSql = "SELECT v.fecha_dia, COUNT(*) AS count " +
                       "FROM (" +
                       "    SELECT COALESCE(fecha_registro::date, NOW()::date - INTERVAL '365 days') as fecha_dia " +
                       "    FROM usuarios " +
                       "    WHERE COALESCE(eliminado, FALSE) = FALSE" +
                       ") v " +
                       "WHERE v.fecha_dia >= NOW()::date - INTERVAL '30 days' " +
                       "GROUP BY v.fecha_dia " +
                       "ORDER BY v.fecha_dia ASC";
    
    ResultSet rsGrowth = stmt.executeQuery(growthSql);
    StringBuilder growthJson = new StringBuilder("[");
    boolean firstGrowth = true;
    while (rsGrowth.next()) {
        if (!firstGrowth) growthJson.append(",");
        firstGrowth = false;
        growthJson.append("{")
                  .append("\"fecha\":\"").append(rsGrowth.getString("fecha_dia")).append("\",")
                  .append("\"cantidad\":").append(rsGrowth.getInt("count"))
                  .append("}");
    }
    growthJson.append("]");
    rsGrowth.close();

    // 3. Top Buyers
    String buyersSql = "SELECT u.nombre, u.usuario, u.correo, " +
                       "COUNT(DISTINCT v.id) as total_compras, " +
                       "COALESCE(SUM(vd.precio * vd.cantidad), 0) as total_gastado " +
                       "FROM usuarios u " +
                       "JOIN ventas v ON v.usuario_id = u.id " +
                       "JOIN venta_detalle vd ON vd.venta_id = v.id " +
                       "WHERE COALESCE(u.eliminado, FALSE) = FALSE " +
                       "AND (v.rol_regalo IS NULL OR v.rol_regalo <> 'recibido') " +
                       "GROUP BY u.id, u.nombre, u.usuario, u.correo " +
                       "ORDER BY total_gastado DESC " +
                       "LIMIT 5";
                       
    ResultSet rsBuyers = stmt.executeQuery(buyersSql);
    StringBuilder buyersJson = new StringBuilder("[");
    boolean firstBuyer = true;
    while (rsBuyers.next()) {
        if (!firstBuyer) buyersJson.append(",");
        firstBuyer = false;
        buyersJson.append("{")
                  .append("\"nombre\":\"").append(escapeJson(rsBuyers.getString("nombre"))).append("\",")
                  .append("\"usuario\":\"").append(escapeJson(rsBuyers.getString("usuario"))).append("\",")
                  .append("\"correo\":\"").append(escapeJson(rsBuyers.getString("correo"))).append("\",")
                  .append("\"compras\":").append(rsBuyers.getInt("total_compras")).append(",")
                  .append("\"gastado\":").append(rsBuyers.getDouble("total_gastado"))
                  .append("}");
    }
    buyersJson.append("]");
    rsBuyers.close();
    
    stmt.close();

    // Construct final JSON response
    StringBuilder json = new StringBuilder();
    json.append("{")
        .append("\"total_usuarios\":").append(totalUsuarios).append(",")
        .append("\"activos_hoy\":").append(activosHoy).append(",")
        .append("\"activos_semana\":").append(activosSemana).append(",")
        .append("\"activos_mes\":").append(activosMes).append(",")
        .append("\"inactivos\":").append(inactivos).append(",")
        .append("\"growth\":").append(growthJson).append(",")
        .append("\"top_buyers\":").append(buyersJson)
        .append("}");

    out.print(json.toString());

} catch (Exception e) {
    out.print("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>
