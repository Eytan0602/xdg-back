<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>

<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/cors.jsp" %>

<%
try {
    String sqlMonthly =
        "SELECT TO_CHAR(v.fecha, 'Mon') as mes, " +
        "EXTRACT(MONTH FROM v.fecha) as num_mes, " +
        "SUM(vd.precio * vd.cantidad) as total " +
        "FROM ventas v " +
        "JOIN venta_detalle vd ON vd.venta_id = v.id " +
        "WHERE EXTRACT(YEAR FROM v.fecha) = EXTRACT(YEAR FROM NOW()) " +
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
        int pct = (int) Math.round((totalesM.get(i) / maxMonthly) * 100);
        monthlyJson.append("{\"label\":\"").append(meses.get(i)).append("\",\"value\":").append(pct).append("}");
    }
    monthlyJson.append("]");

    String sqlDaily =
        "SELECT TO_CHAR(v.fecha, 'Dy') as dia, " +
        "SUM(vd.precio * vd.cantidad) as total " +
        "FROM ventas v " +
        "JOIN venta_detalle vd ON vd.venta_id = v.id " +
        "WHERE v.fecha >= NOW() - INTERVAL '7 days' " +
        "GROUP BY dia, v.fecha ORDER BY v.fecha";

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
        int pct = (int) Math.round((totalesD.get(i) / maxDaily) * 100);
        dailyJson.append("{\"label\":\"").append(dias.get(i)).append("\",\"value\":").append(pct).append("}");
    }
    dailyJson.append("]");

    String sqlCat =
        "SELECT c.nombre, COUNT(vd.id) as ventas " +
        "FROM venta_detalle vd " +
        "JOIN juego_categoria jc ON jc.juego_id = vd.juego_id " +
        "JOIN categorias c ON c.id = jc.categoria_id " +
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


    ResultSet rsCli = con.prepareStatement("SELECT COUNT(DISTINCT usuario_id) FROM ventas").executeQuery();
    int newClients = rsCli.next() ? rsCli.getInt(1) : 0;

    int txOffset = 0;
    int txLimit  = 6;
    try {
        if (request.getParameter("offset") != null)
            txOffset = Integer.parseInt(request.getParameter("offset"));
        if (request.getParameter("limit") != null)
            txLimit = Integer.parseInt(request.getParameter("limit"));
    } catch (NumberFormatException ignored) {}

    String sqlTransacciones =
        "SELECT u.nombre, u.usuario, j.titulo, vd.precio, vd.cantidad, v.fecha " +
        "FROM ventas v " +
        "JOIN usuarios u ON u.id = v.usuario_id " +
        "JOIN venta_detalle vd ON vd.venta_id = v.id " +
        "JOIN juegos j ON j.id = vd.juego_id " +
        "ORDER BY v.fecha DESC " +
        "LIMIT " + txLimit + " OFFSET " + txOffset;

    ResultSet rsPaginado = con.prepareStatement(sqlTransacciones).executeQuery();
    StringBuilder txJson = new StringBuilder("[");
    boolean primerTx = true;

    while (rsPaginado.next()) {
        if (!primerTx) txJson.append(",");
        primerTx = false;

        String txNombre   = rsPaginado.getString("nombre").replace("\"", "\\\"");
        String txUsuario  = rsPaginado.getString("usuario").replace("\"", "\\\"");
        String txTitulo   = rsPaginado.getString("titulo").replace("\"", "\\\"");
        double txPrecio   = rsPaginado.getDouble("precio");
        int    txCantidad = rsPaginado.getInt("cantidad");
        String txFecha    = rsPaginado.getString("fecha").substring(0, 10);

        txJson.append("{")
              .append("\"nombre\":\"").append(txNombre).append("\",")
              .append("\"usuario\":\"").append(txUsuario).append("\",")
              .append("\"juego\":\"").append(txTitulo).append("\",")
              .append("\"precio\":").append(txPrecio).append(",")
              .append("\"cantidad\":").append(txCantidad).append(",")
              .append("\"fecha\":\"").append(txFecha).append("\"")
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
    out.print("{\"error\":\"" + e.getMessage().replace("\"","") + "\"}");
}
%>