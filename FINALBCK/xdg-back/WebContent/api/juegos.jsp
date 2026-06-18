<%@ page import="java.sql.*, java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>
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
Map<String,String> jsonBody = parseJsonBody(request);
String method = request.getMethod();
String role = (String) session.getAttribute("user_role");
boolean esAdmin = "admin".equals(role);

try {
  if ("GET".equalsIgnoreCase(method)) {

    String id = param(request, jsonBody, "id");
    String q = param(request, jsonBody, "q");
    String categoriaId = param(request, jsonBody, "categoria_id");

    if (id != null && !id.trim().isEmpty()) {
      String sql =
        "SELECT j.*, " +
        "d.porcentaje, " +
        "d.precio_original, " +
        "ROUND(d.precio_original * (1 - d.porcentaje / 100.0), 2) AS precio_con_descuento " +
        "FROM juegos j " +
        "LEFT JOIN descuentos d " +
        "ON d.juego_id = j.id " +
        "AND d.activo = TRUE " +
        "AND d.fecha_fin > NOW() " +
        "WHERE j.id = ?";

      PreparedStatement psGet = con.prepareStatement(sql);
      psGet.setInt(1, Integer.parseInt(id));
      ResultSet rsGet = psGet.executeQuery();

      if (rsGet.next()) {
        out.print("{"
          + "\"id\":" + rsGet.getInt("id") + ","
          + "\"titulo\":\"" + escapeJson(rsGet.getString("titulo")) + "\","
          + "\"descripcion\":\"" + escapeJson(rsGet.getString("descripcion")) + "\","
          + "\"imagen_url\":\"" + escapeJson(rsGet.getString("imagen_url")) + "\","
          + "\"video_url\":\"" + escapeJson(rsGet.getString("video_url")) + "\","
          + "\"fecha_lanzamiento\":" + (rsGet.getDate("fecha_lanzamiento") != null ? "\"" + rsGet.getDate("fecha_lanzamiento").toString() + "\"" : "null") + ","
          + "\"precio\":" + rsGet.getDouble("precio") + ","
          + "\"precio_original\":" + (rsGet.getObject("precio_original") != null ? rsGet.getDouble("precio_original") : "null") + ","
          +"\"precio_base\":" + rsGet.getDouble("precio") + "," // Precio de la tabla juegos
          + "\"precio_final\":" + (rsGet.getObject("porcentaje") != null ? rsGet.getDouble("precio_con_descuento") : rsGet.getDouble("precio")) + ","
          + "\"porcentaje\":" + (rsGet.getObject("porcentaje") != null ? rsGet.getDouble("porcentaje") : "null")
          + "}");
      } else {
        out.print("{\"error\":\"not_found\"}");
      }
      return;
    }

    StringBuilder sqlList = new StringBuilder();
    sqlList.append("SELECT DISTINCT j.* FROM juegos j WHERE 1=1 ");

    if (categoriaId != null && !categoriaId.trim().isEmpty()) {
      sqlList.append(" AND EXISTS (")
             .append("SELECT 1 FROM juego_categoria jc ")
             .append("WHERE jc.juego_id = j.id AND jc.categoria_id = ?")
             .append(") ");
    }

    if (q != null && !q.trim().isEmpty()) {
      sqlList.append(" AND j.titulo ILIKE ? ");
    }

    sqlList.append(" ORDER BY j.updated_at DESC");

    PreparedStatement psList = con.prepareStatement(sqlList.toString());
    int idx = 1;

    if (categoriaId != null && !categoriaId.trim().isEmpty()) {
      psList.setInt(idx++, Integer.parseInt(categoriaId));
    }

    if (q != null && !q.trim().isEmpty()) {
      psList.setString(idx++, "%" + q + "%");
    }

    ResultSet rsList = psList.executeQuery();
    StringBuilder json = new StringBuilder("[");
    boolean first = true;

    while (rsList.next()) {
      if (!first) json.append(",");
      json.append("{")
        .append("\"id\":").append(rsList.getInt("id")).append(",")
        .append("\"titulo\":\"").append(escapeJson(rsList.getString("titulo"))).append("\",")
        .append("\"descripcion\":\"").append(escapeJson(rsList.getString("descripcion"))).append("\",")
        .append("\"imagen_url\":\"").append(escapeJson(rsList.getString("imagen_url"))).append("\",")
        .append("\"video_url\":\"").append(escapeJson(rsList.getString("video_url"))).append("\",")
        .append("\"fecha_lanzamiento\":").append(
            rsList.getDate("fecha_lanzamiento") != null
              ? "\"" + rsList.getDate("fecha_lanzamiento").toString() + "\""
              : "null"
        ).append(",")
        .append("\"precio\":").append(rsList.getDouble("precio"))
        .append("}");
      first = false;
    }

    json.append("]");
    out.print(json.toString());
    return;
  }

  else if ("POST".equalsIgnoreCase(method)) {
    if (!esAdmin) { out.print("{\"error\":\"unauthorized\"}"); return; }

    String titulo = param(request, jsonBody, "titulo");
    String slug = param(request, jsonBody, "slug");
    String descripcion = param(request, jsonBody, "descripcion");
    String imagen_url = param(request, jsonBody, "imagen_url");
    String video_url = param(request, jsonBody, "video_url");
    String fecha_lanzamiento = param(request, jsonBody, "fecha_lanzamiento");
    String precioS = param(request, jsonBody, "precio");
    String categoriaId = param(request, jsonBody, "categoria_id");

    if (titulo == null || precioS == null) {
      out.print("{\"error\":\"missing fields: titulo, precio\"}");
      return;
    }

    double precio = Double.parseDouble(precioS);

    String insertSql =
      "INSERT INTO juegos(titulo, slug, descripcion, imagen_url, video_url, fecha_lanzamiento, precio, updated_at) " +
      "VALUES(?,?,?,?,?,?,?,CURRENT_TIMESTAMP)";

    PreparedStatement psInsert = con.prepareStatement(insertSql, Statement.RETURN_GENERATED_KEYS);
    psInsert.setString(1, titulo);
    psInsert.setString(2, slug != null ? slug : "");
    psInsert.setString(3, descripcion != null ? descripcion : "");
    psInsert.setString(4, imagen_url != null ? imagen_url : "");
    psInsert.setString(5, video_url != null ? video_url : "");
    if (fecha_lanzamiento != null && !fecha_lanzamiento.trim().isEmpty()) {
      if (fecha_lanzamiento.contains("T")) fecha_lanzamiento = fecha_lanzamiento.split("T")[0];
      psInsert.setDate(6, java.sql.Date.valueOf(fecha_lanzamiento));
    } else {
      psInsert.setNull(6, java.sql.Types.DATE);
    }
    psInsert.setDouble(7, precio);

    int affected = psInsert.executeUpdate();
    if (affected == 0) { out.print("{\"success\":false}"); return; }

    ResultSet keys = psInsert.getGeneratedKeys();
    Integer newId = null;
    if (keys.next()) newId = keys.getInt(1);

    if (newId != null && categoriaId != null && !categoriaId.trim().isEmpty()) {
      try {
        PreparedStatement linkPs = con.prepareStatement("INSERT INTO juego_categoria(juego_id, categoria_id) VALUES(?,?)");
        linkPs.setInt(1, newId);
        linkPs.setInt(2, Integer.parseInt(categoriaId));
        linkPs.executeUpdate();
      } catch (Exception e) {}
    }

    out.print("{\"success\":true");
    if (newId != null) out.print(",\"id\":" + newId);
    out.print("}");
    return;
  }

  else if ("PUT".equalsIgnoreCase(method)) {
    if (!esAdmin) { out.print("{\"error\":\"unauthorized\"}"); return; }

    String id = param(request, jsonBody, "id");
    if (id == null) { out.print("{\"error\":\"missing id\"}"); return; }

    String titulo = param(request, jsonBody, "titulo");
    String slug = param(request, jsonBody, "slug");
    String descripcion = param(request, jsonBody, "descripcion");
    String imagen_url = param(request, jsonBody, "imagen_url");
    String video_url = param(request, jsonBody, "video_url");
    String fecha_lanzamiento = param(request, jsonBody, "fecha_lanzamiento");
    String precioS = param(request, jsonBody, "precio");
    String categoriaId = param(request, jsonBody, "categoria_id");

    StringBuilder update = new StringBuilder("UPDATE juegos SET ");
    List<Object> params = new ArrayList<Object>();

    if (titulo != null)      { update.append("titulo=?,");       params.add(titulo); }
    if (slug != null)        { update.append("slug=?,");         params.add(slug); }
    if (descripcion != null) { update.append("descripcion=?,");  params.add(descripcion); }
    if (imagen_url != null)  { update.append("imagen_url=?,");   params.add(imagen_url); }
    if (video_url != null)   { update.append("video_url=?,");    params.add(video_url); }
    if (fecha_lanzamiento != null && !fecha_lanzamiento.trim().isEmpty()) {
      update.append("fecha_lanzamiento=?,");
      if (fecha_lanzamiento.contains("T")) fecha_lanzamiento = fecha_lanzamiento.split("T")[0];
      params.add(java.sql.Date.valueOf(fecha_lanzamiento));
    }
    if (precioS != null) {
      update.append("precio=?,");
      params.add(Double.parseDouble(precioS));
    }
    update.append("updated_at=CURRENT_TIMESTAMP,");
    update.setLength(update.length() - 1);
    update.append(" WHERE id=?");

    PreparedStatement psPut = con.prepareStatement(update.toString());
    int idxPut = 1;
    for (Object o : params) {
      if (o instanceof String)        psPut.setString(idxPut++, (String) o);
      else if (o instanceof Double)   psPut.setDouble(idxPut++, (Double) o);
      else if (o instanceof java.sql.Date) psPut.setDate(idxPut++, (java.sql.Date) o);
      else                            psPut.setObject(idxPut++, o);
    }
    psPut.setInt(idxPut, Integer.parseInt(id));
    psPut.executeUpdate();

    if (categoriaId != null) {
      try {
        PreparedStatement delCat = con.prepareStatement("DELETE FROM juego_categoria WHERE juego_id = ?");
        delCat.setInt(1, Integer.parseInt(id));
        delCat.executeUpdate();

        if (!categoriaId.trim().isEmpty()) {
          PreparedStatement insCat = con.prepareStatement("INSERT INTO juego_categoria(juego_id, categoria_id) VALUES(?,?)");
          insCat.setInt(1, Integer.parseInt(id));
          insCat.setInt(2, Integer.parseInt(categoriaId));
          insCat.executeUpdate();
        }
      } catch (Exception e) {}
    }

    out.print("{\"success\":true}");
    return;
  }

  else if ("DELETE".equalsIgnoreCase(method)) {
    if (!esAdmin) { out.print("{\"error\":\"unauthorized\"}"); return; }

    String id = param(request, jsonBody, "id");
    if (id == null) { out.print("{\"error\":\"missing id\"}"); return; }

    try {
      PreparedStatement delMap = con.prepareStatement("DELETE FROM juego_categoria WHERE juego_id = ?");
      delMap.setInt(1, Integer.parseInt(id));
      delMap.executeUpdate();

      PreparedStatement delJuego = con.prepareStatement("DELETE FROM juegos WHERE id = ?");
      delJuego.setInt(1, Integer.parseInt(id));
      int rDel = delJuego.executeUpdate();

      out.print("{\"deleted\":" + (rDel > 0) + "}");
    } catch (Exception e) {
      out.print("{\"error\":\"" + e.getMessage().replace("\"", "") + "\"}");
    }
    return;
  }

  else {
    out.print("{\"error\":\"invalid method\"}");
    return;
  }

} catch (Exception e) {
  out.print("{\"error\":\"" + e.getMessage().replace("\"", "") + "\"}");
}
%>