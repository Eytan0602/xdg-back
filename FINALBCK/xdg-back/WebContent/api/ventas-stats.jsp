<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>

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
try {
    String subRole = (String) session.getAttribute("sub_role");
    if ("SOPORTE".equalsIgnoreCase(subRole)) {
        out.print("{\"error\":\"unauthorized\"}");
        return;
    }
    
    // Monthly stats excluding duplicates
    String sqlMonthly =
        "SELECT TO_CHAR(v.fecha, 'Mon') as mes, " +
        "EXTRACT(MONTH FROM v.fecha) as num_mes, " +
        "SUM(vd.precio * vd.cantidad) as total " +
        "FROM ventas v " +
        "JOIN venta_detalle vd ON vd.venta_id = v.id " +
        "WHERE EXTRACT(YEAR FROM v.fecha) = EXTRACT(YEAR FROM NOW()) " +
        "AND (v.rol_regalo IS NULL OR v.rol_regalo <> 'recibido') " +
        "GROUP BY mes, num_mes ORDER BY num_mes";

    PreparedStatement psM = con.prepareStatement(sqlMonthly);
    ResultSet rsM = psM.executeQuery();
    List<String> meses = new ArrayList<String>();
    List<Double> totalesM = new ArrayList<Double>();
    double maxMonthly = 1;
    double sumMonthlyTotal = 0;

    while (rsM.next()) {
        String mes = rsM.getString("mes").toUpperCase();
        double total = rsM.getDouble("total");
        meses.add(mes);
        totalesM.add(total);
        sumMonthlyTotal += total;
        if (total > maxMonthly) maxMonthly = total;
    }

    StringBuilder monthlyJson = new StringBuilder("[");
    for (int i = 0; i < meses.size(); i++) {
        if (i > 0) monthlyJson.append(",");
        monthlyJson.append("{\"label\":\"").append(meses.get(i)).append("\",\"value\":").append(totalesM.get(i)).append("}");
    }
    monthlyJson.append("]");

    int daysParam = 7;
    if (request.getParameter("days") != null) {
        try { daysParam = Integer.parseInt(request.getParameter("days")); } catch (Exception e){}
    }
    String fmt = daysParam <= 7 ? "Dy" : "DD/MM";
    
    // Daily stats excluding duplicates
    String sqlDaily =
    "SELECT TO_CHAR(v.fecha::date, '" + fmt + "') as dia, " +
    "SUM(vd.precio * vd.cantidad) as total " +
    "FROM ventas v " +
    "JOIN venta_detalle vd ON vd.venta_id = v.id " +
    "WHERE v.fecha >= NOW() - INTERVAL '" + daysParam + " days' " +
    "AND (v.rol_regalo IS NULL OR v.rol_regalo <> 'recibido') " +
    "GROUP BY dia, v.fecha::date ORDER BY v.fecha::date";

    PreparedStatement psD = con.prepareStatement(sqlDaily);
    ResultSet rsD = psD.executeQuery();
    List<String> dias = new ArrayList<String>();
    List<Double> totalesD = new ArrayList<Double>();
    double maxDaily = 1;
    double sumDailyTotal = 0;

    while (rsD.next()) {
        dias.add(rsD.getString("dia").toUpperCase());
        double val = rsD.getDouble("total");
        totalesD.add(val);
        sumDailyTotal += val;
        if (val > maxDaily) maxDaily = val;
    }

    StringBuilder dailyJson = new StringBuilder("[");
    for (int i = 0; i < dias.size(); i++) {
        if (i > 0) dailyJson.append(",");
        dailyJson.append("{\"label\":\"").append(dias.get(i)).append("\",\"value\":").append(totalesD.get(i)).append("}");
    }
    dailyJson.append("]");

    // Category distribution excluding duplicates
    String sqlCat =
        "SELECT c.nombre, COUNT(vd.id) as ventas " +
        "FROM venta_detalle vd " +
        "JOIN ventas v ON v.id = vd.venta_id " +
        "JOIN juego_categoria jc ON jc.juego_id = vd.juego_id " +
        "JOIN categorias c ON c.id = jc.categoria_id " +
        "WHERE (v.rol_regalo IS NULL OR v.rol_regalo <> 'recibido') " +
        "GROUP BY c.nombre ORDER BY ventas DESC";

    ResultSet rsCat = con.prepareStatement(sqlCat).executeQuery();
    List<String> catNombres = new ArrayList<String>();
    List<Integer> catVentas = new ArrayList<Integer>();
    int totalVentasGlobal = 0;

    while (rsCat.next()) {
        catNombres.add(rsCat.getString("nombre"));
        int vCat = rsCat.getInt("ventas");
        catVentas.add(vCat);
        totalVentasGlobal += vCat;
    }

    StringBuilder catsJson = new StringBuilder("[");
    String[] colors = {"#8b5cf6","#ffb38a","#ffb85e","#d8d1eb","#60a5fa","#34d399"};
    for (int i = 0; i < catNombres.size(); i++) {
        if (i > 0) catsJson.append(",");
        int pct = totalVentasGlobal > 0 ? (int)Math.round((catVentas.get(i)*100.0)/totalVentasGlobal) : 0;
        catsJson.append("{\"label\":\"").append(catNombres.get(i).toUpperCase())
                .append("\",\"pct\":").append(pct)
                .append(",\"color\":\"").append(colors[i % colors.length]).append("\"}");
    }
    catsJson.append("]");

    // Clients total count excluding duplicates
    ResultSet rsCli = con.prepareStatement("SELECT COUNT(DISTINCT usuario_id) FROM ventas WHERE (rol_regalo IS NULL OR rol_regalo <> 'recibido')").executeQuery();
    int newClients = rsCli.next() ? rsCli.getInt(1) : 0;

    int txOffset = 0;
    int txLimit  = 6;
    try {
        if (request.getParameter("offset") != null)
            txOffset = Integer.parseInt(request.getParameter("offset"));
        if (request.getParameter("limit") != null)
            txLimit = Integer.parseInt(request.getParameter("limit"));
    } catch (NumberFormatException ignored) {}

    // Transactions query excluding duplicates and including recipient details
    String sqlTransacciones =
        "SELECT v.id as venta_id, v.fecha, " +
        "u.nombre, u.usuario, u.correo, " +
        "COALESCE(v.es_regalo, FALSE) as es_regalo, " +
        "r.nombre as dest_nombre, r.usuario as dest_usuario, r.correo as dest_correo, " +
        "STRING_AGG(j.titulo, ', ') as juegos, " +
        "SUM(vd.precio * vd.cantidad) as total_precio, " +
        "SUM(vd.cantidad) as total_cantidad " +
        "FROM ventas v " +
        "JOIN usuarios u ON u.id = v.usuario_id " +
        "LEFT JOIN usuarios r ON r.id = v.relacionado_usuario_id " +
        "JOIN venta_detalle vd ON vd.venta_id = v.id " +
        "JOIN juegos j ON j.id = vd.juego_id " +
        "WHERE (v.rol_regalo IS NULL OR v.rol_regalo <> 'recibido') " +
        "GROUP BY v.id, v.fecha, u.nombre, u.usuario, u.correo, v.es_regalo, r.nombre, r.usuario, r.correo " +
        "ORDER BY v.fecha DESC " +
        "LIMIT " + txLimit + " OFFSET " + txOffset;

    ResultSet rsPaginado = con.prepareStatement(sqlTransacciones).executeQuery();
    StringBuilder txJson = new StringBuilder("[");
    boolean primerTx = true;

    while (rsPaginado.next()) {
        if (!primerTx) txJson.append(",");
        primerTx = false;

        String txNombre   = rsPaginado.getString("nombre");
        String txUsuario  = rsPaginado.getString("usuario");
        String txCorreo   = rsPaginado.getString("correo");
        String txTitulo   = rsPaginado.getString("juegos");
        double totalPrecio = rsPaginado.getDouble("total_precio");
        int totalCantidad = rsPaginado.getInt("total_cantidad");
        double txPrecio   = totalCantidad > 0 ? totalPrecio / totalCantidad : 0;
        int    txCantidad = totalCantidad;
        String txFecha    = rsPaginado.getString("fecha").substring(0, 19); // Keep full date time
        boolean txEsRegalo = rsPaginado.getBoolean("es_regalo");
        String destNombre = rsPaginado.getString("dest_nombre");
        String destUsuario = rsPaginado.getString("dest_usuario");
        String destCorreo = rsPaginado.getString("dest_correo");

        txJson.append("{")
              .append("\"nombre\":\"").append(escapeJson(txNombre)).append("\",")
              .append("\"usuario\":\"").append(escapeJson(txUsuario)).append("\",")
              .append("\"correo\":\"").append(escapeJson(txCorreo)).append("\",")
              .append("\"juego\":\"").append(escapeJson(txTitulo)).append("\",")
              .append("\"precio\":").append(txPrecio).append(",")
              .append("\"cantidad\":").append(txCantidad).append(",")
              .append("\"fecha\":\"").append(escapeJson(txFecha)).append("\",")
              .append("\"es_regalo\":").append(txEsRegalo).append(",")
              .append("\"dest_nombre\":\"").append(escapeJson(destNombre)).append("\",")
              .append("\"dest_usuario\":\"").append(escapeJson(destUsuario)).append("\",")
              .append("\"dest_correo\":\"").append(escapeJson(destCorreo)).append("\"")
              .append("}");
    }
    txJson.append("]");

    StringBuilder json = new StringBuilder();
    json.append("{")
        .append("\"monthly\":").append(monthlyJson).append(",")
        .append("\"daily\":").append(dailyJson).append(",")
        .append("\"categories\":").append(catsJson).append(",")
        .append("\"transacciones\":").append(txJson).append(",")
        .append("\"monthlyTotal\":").append(sumMonthlyTotal).append(",")
        .append("\"monthlyChange\":\"+12.5%\",")
        .append("\"dailyTotal\":").append(sumDailyTotal).append(",")
        .append("\"dailyChange\":\"+5%\",")
        .append("\"newClients\":").append(newClients).append(",")
        .append("\"clientsChange\":\"+2%\",")
        .append("\"conversionRate\":2.4,")
        .append("\"conversionChange\":\"+0.2%\"")
        .append("}");

    out.print(json.toString());

} catch(Exception e) {
    out.print("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>