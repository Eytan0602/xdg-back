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
    String rango = request.getParameter("rango");
    if (rango == null) rango = "diario";
    String mesParam = request.getParameter("mes");

    String dateGroup = "CAST(v.fecha AS DATE)";
    String whereClause = "";

    if ("semanal".equalsIgnoreCase(rango)) {
        dateGroup = "DATE_TRUNC('week', v.fecha)";
    } else if ("mensual".equalsIgnoreCase(rango)) {
        if (mesParam != null && !mesParam.isEmpty()) {
            try {
                String[] parts = mesParam.split(",");
                StringBuilder inClause = new StringBuilder();
                for (String p : parts) {
                    int m = Integer.parseInt(p.trim());
                    if (inClause.length() > 0) inClause.append(",");
                    inClause.append(m);
                }
                if (inClause.length() > 0) {
                    dateGroup = "CAST(v.fecha AS DATE)";
                    whereClause = "WHERE EXTRACT(MONTH FROM v.fecha) IN (" + inClause.toString() + ") AND EXTRACT(YEAR FROM v.fecha) = EXTRACT(YEAR FROM NOW()) ";
                }
            } catch(Exception e){}
        } else {
            dateGroup = "DATE_TRUNC('month', v.fecha)";
        }
    }

    String sql = "SELECT " + dateGroup + " AS fecha_grupo, " +
                 "SUM(vd.precio * vd.cantidad) AS total_ingreso " +
                 "FROM ventas v " +
                 "JOIN venta_detalle vd ON v.id = vd.venta_id " +
                 whereClause +
                 "GROUP BY " + dateGroup + " " +
                 "ORDER BY fecha_grupo ASC";

    PreparedStatement ps = con.prepareStatement(sql);
    ResultSet rs = ps.executeQuery();

    List<String> reportes = new ArrayList<String>();
    while (rs.next()) {
        String fecha = rs.getString("fecha_grupo");
        if (fecha != null && fecha.length() > 10) {
            fecha = fecha.substring(0, 10);
        }
        double totalIngreso = rs.getDouble("total_ingreso");
        double totalEgreso = totalIngreso * 0.60; 
        double gananciaNeta = totalIngreso - totalEgreso;

        String item = "{" +
            "\"fecha\": \"" + escapeJson(fecha) + "\", " +
            "\"ingresos\": " + totalIngreso + ", " +
            "\"egresos\": " + totalEgreso + ", " +
            "\"ganancia\": " + gananciaNeta + 
        "}";
        reportes.add(item);
    }
    
    out.print("[" + String.join(",", reportes) + "]");

} catch (Exception e) {
    out.print("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>
