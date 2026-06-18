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
  if("GET".equalsIgnoreCase(method)) {
    String id = param(request, jsonBody, "id");
    String q = param(request, jsonBody, "q");
    String categoriaId = param(request, jsonBody, "categoria_id");

    if(id != null && !id.trim().isEmpty()) {
      String sql = "SELECT j.*, jc.categoria_id, c.nombre AS categoria_nombre " +
                   "FROM juegos j " +
                   "LEFT JOIN juego_categoria jc ON jc.juego_id = j.id " +
                   "LEFT JOIN categorias c ON c.id = jc.categoria_id " +
                   "WHERE j.id = ?";
      PreparedStatement ps = con.prepareStatement(sql);
      ps.setInt(1, Integer.parseInt(id));
      ResultSet rs = ps.executeQuery();
      if(rs.next()) {
        String desc  = rs.getString("descripcion")       != null ? rs.getString("descripcion").replace("\"","'")       : "";
        String slug  = rs.getString("slug")              != null ? rs.getString("slug")                                : "";
        String img   = rs.getString("imagen_url")        != null ? rs.getString("imagen_url")                         : "";
        String vid   = rs.getString("video_url")         != null ? rs.getString("video_url")                          : "";
        String fecha = rs.getString("fecha_lanzamiento") != null ? rs.getString("fecha_lanzamiento")                  : "";
        String categoriaNombre = rs.getString("categoria_nombre") != null ? rs.getString("categoria_nombre") : "";
        Integer categoria_id = rs.getObject("categoria_id") != null ? rs.getInt("categoria_id") : null;

        out.print("{");
        out.print("\"id\":" + rs.getInt("id") + ",");
        out.print("\"titulo\":\"" + escapeJson(rs.getString("titulo")) + "\",");
        out.print("\"slug\":\"" + escapeJson(slug) + "\",");
        out.print("\"descripcion\":\"" + escapeJson(desc) + "\",");
        out.print("\"imagen_url\":\"" + escapeJson(img) + "\",");
        out.print("\"video_url\":\"" + escapeJson(vid) + "\",");
        out.print("\"fecha_lanzamiento\":\"" + escapeJson(fecha) + "\",");
        out.print("\"precio\":" + rs.getDouble("precio") + ",");
        out.print("\"categoria_id\":" + (categoria_id != null ? categoria_id : "null") + ",");
        out.print("\"categoria_nombre\":\"" + escapeJson(categoriaNombre) + "\"");
        out.print("}");
      } else {
        out.print("{\"error\":\"not_found\"}");
      }
      return;
    }

    StringBuilder sql = new StringBuilder(
      "SELECT j.*, jc.categoria_id, c.nombre AS categoria_nombre FROM juegos j " +
      "LEFT JOIN juego_categoria jc ON jc.juego_id = j.id " +
      "LEFT JOIN categorias c ON c.id = jc.categoria_id"
    );
    boolean where = false;
    if(categoriaId != null && !categoriaId.trim().isEmpty()) {
      sql.append(" WHERE jc.categoria_id = ?");
      where = true;
    }
    if(q != null && !q.trim().isEmpty()) {
      sql.append(where ? " AND " : " WHERE ");
      sql.append("j.titulo ILIKE ?");
    }
sql.append(" ORDER BY j.updated_at DESC");
    PreparedStatement ps = con.prepareStatement(sql.toString());
    int idx=1;
    if(categoriaId != null && !categoriaId.trim().isEmpty()) {
      ps.setInt(idx++, Integer.parseInt(categoriaId));
    }
    if(q != null && !q.trim().isEmpty()) {
      ps.setString(idx++, "%" + q + "%");
    }

    ResultSet rs = ps.executeQuery();
    StringBuilder json = new StringBuilder("[");
    boolean first = true;
    while(rs.next()) {

    if(!first) json.append(",");

    String updatedAt =
        rs.getString("updated_at") != null
        ? rs.getString("updated_at")
        : "";

    String desc  = rs.getString("descripcion") != null ? rs.getString("descripcion").replace("\"","'") : "";
    String slug  = rs.getString("slug") != null ? rs.getString("slug") : "";
    String img   = rs.getString("imagen_url") != null ? rs.getString("imagen_url") : "";
    String vid   = rs.getString("video_url") != null ? rs.getString("video_url") : "";
    String fecha = rs.getString("fecha_lanzamiento") != null ? rs.getString("fecha_lanzamiento") : "";
    String categoriaNombre = rs.getString("categoria_nombre") != null ? rs.getString("categoria_nombre") : "";
    Integer categoria_id = rs.getObject("categoria_id") != null ? rs.getInt("categoria_id") : null;

    json.append("{")
        .append("\"id\":").append(rs.getInt("id")).append(",")
        .append("\"titulo\":\"").append(escapeJson(rs.getString("titulo"))).append("\",")
        .append("\"updated_at\":\"").append(escapeJson(updatedAt)).append("\",")
        .append("\"slug\":\"").append(escapeJson(slug)).append("\",")
        .append("\"descripcion\":\"").append(escapeJson(desc)).append("\",")
        .append("\"imagen_url\":\"").append(escapeJson(img)).append("\",")
        .append("\"video_url\":\"").append(escapeJson(vid)).append("\",")
        .append("\"fecha_lanzamiento\":\"").append(escapeJson(fecha)).append("\",")
        .append("\"precio\":").append(rs.getDouble("precio")).append(",")
        .append("\"categoria_id\":").append(categoria_id != null ? categoria_id : "null").append(",")
        .append("\"categoria_nombre\":\"").append(escapeJson(categoriaNombre)).append("\"")
        .append("}");

    first = false;
}
    json.append("]");
    out.print(json.toString());
    return;
  }

  else if("POST".equalsIgnoreCase(method)) {
    if(!esAdmin) { out.print("{\"error\":\"unauthorized\"}"); return; }

    String titulo = param(request, jsonBody, "titulo");
    String slug = param(request, jsonBody, "slug");
    String descripcion = param(request, jsonBody, "descripcion");
    String imagen_url = param(request, jsonBody, "imagen_url");
    String video_url = param(request, jsonBody, "video_url");
    String fecha_lanzamiento = param(request, jsonBody, "fecha_lanzamiento");
    String precioS = param(request, jsonBody, "precio");
    String categoriaId = param(request, jsonBody, "categoria_id");

    if(titulo == null || precioS == null) {
      out.print("{\"error\":\"missing fields: titulo, precio\"}");
      return;
    }

    double precio = Double.parseDouble(precioS);

String insertSql =
"INSERT INTO juegos(titulo, slug, descripcion, imagen_url, video_url, fecha_lanzamiento, precio, updated_at) " +
"VALUES(?,?,?,?,?,?,?,CURRENT_TIMESTAMP)";
    PreparedStatement ps = con.prepareStatement(insertSql, Statement.RETURN_GENERATED_KEYS);
    ps.setString(1, titulo);
    ps.setString(2, slug != null ? slug : "");
    ps.setString(3, descripcion != null ? descripcion : "");
    ps.setString(4, imagen_url != null ? imagen_url : "");
    ps.setString(5, video_url != null ? video_url : "");
    if (fecha_lanzamiento != null && !fecha_lanzamiento.trim().isEmpty()) {
    if (fecha_lanzamiento.contains("T")) fecha_lanzamiento = fecha_lanzamiento.split("T")[0];
    java.sql.Date sqlDate = java.sql.Date.valueOf(fecha_lanzamiento); // espera YYYY-MM-DD
    ps.setDate(6, sqlDate);
    } else {
    ps.setNull(6, java.sql.Types.DATE);
    }
    ps.setDouble(7, precio);

    int affected = ps.executeUpdate();
    if(affected == 0) { out.print("{\"success\":false}"); return; }

    ResultSet keys = ps.getGeneratedKeys();
    Integer newId = null;
    if(keys.next()) newId = keys.getInt(1);

    if(newId != null && categoriaId != null && !categoriaId.trim().isEmpty()) {
      try {
        String linkSql = "INSERT INTO juego_categoria(juego_id, categoria_id) VALUES(?,?)";
        PreparedStatement linkPs = con.prepareStatement(linkSql);
        linkPs.setInt(1, newId);
        linkPs.setInt(2, Integer.parseInt(categoriaId));
        linkPs.executeUpdate();
      } catch(Exception e){ }
    }

    out.print("{\"success\":true");
    if(newId != null) out.print(",\"id\":" + newId);
    out.print("}");
    return;
  }

  else if("PUT".equalsIgnoreCase(method)) {
    if(!esAdmin) { out.print("{\"error\":\"unauthorized\"}"); return; }

    String id = param(request, jsonBody, "id");
    if(id == null) { out.print("{\"error\":\"missing id\"}"); return; }

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
        if(titulo != null) { update.append("titulo=?,"); params.add(titulo); }
    if(slug != null) { update.append("slug=?,"); params.add(slug); }
    if(descripcion != null) { update.append("descripcion=?,"); params.add(descripcion); }
    if(imagen_url != null) { update.append("imagen_url=?,"); params.add(imagen_url); }
    if(video_url != null) { update.append("video_url=?,"); params.add(video_url); }
    if (fecha_lanzamiento != null && !fecha_lanzamiento.trim().isEmpty()) {
    update.append("fecha_lanzamiento=?,");
    if (fecha_lanzamiento.contains("T")) fecha_lanzamiento = fecha_lanzamiento.split("T")[0];
    params.add(java.sql.Date.valueOf(fecha_lanzamiento));
    }
    if(precioS != null) {
    update.append("precio=?,");
    params.add(Double.parseDouble(precioS));
}
update.append("updated_at=CURRENT_TIMESTAMP,");
  update.setLength(update.length()-1);
  update.append(" WHERE id=?");
      PreparedStatement ps = con.prepareStatement(update.toString());
      int idx = 1;
      for (Object o : params) {
        if (o instanceof String) {
        ps.setString(idx++, (String)o);
        } else if (o instanceof Double) {
        ps.setDouble(idx++, (Double)o);
        } else if (o instanceof java.sql.Date) {
        ps.setDate(idx++, (java.sql.Date)o);
        } else {
        ps.setObject(idx++, o);
    }
    }
      ps.setInt(idx, Integer.parseInt(id));
      ps.executeUpdate();
    

    if(categoriaId != null) {
      try {
        PreparedStatement del = con.prepareStatement("DELETE FROM juego_categoria WHERE juego_id = ?");
        del.setInt(1, Integer.parseInt(id));
        del.executeUpdate();

        if(!categoriaId.trim().isEmpty()) {
          PreparedStatement ins = con.prepareStatement("INSERT INTO juego_categoria(juego_id, categoria_id) VALUES(?,?)");
          ins.setInt(1, Integer.parseInt(id));
          ins.setInt(2, Integer.parseInt(categoriaId));
          ins.executeUpdate();
        }
      } catch(Exception e) { }
    }

    out.print("{\"success\":true}");
    return;
  }

  else if("DELETE".equalsIgnoreCase(method)) {
    if(!esAdmin) { out.print("{\"error\":\"unauthorized\"}"); return; }
    String id = param(request, jsonBody, "id");
    if(id == null) { out.print("{\"error\":\"missing id\"}"); return; }

    try {
      PreparedStatement delMap = con.prepareStatement("DELETE FROM juego_categoria WHERE juego_id = ?");
      delMap.setInt(1, Integer.parseInt(id));
      delMap.executeUpdate();

      PreparedStatement del = con.prepareStatement("DELETE FROM juegos WHERE id = ?");
      del.setInt(1, Integer.parseInt(id));
      int r = del.executeUpdate();

      out.print("{\"deleted\":" + (r>0) + "}");
    } catch(Exception e) {
      out.print("{\"error\":\"" + e.getMessage().replace("\"","") + "\"}");
    }
    return;
  }

  else {
    out.print("{\"error\":\"invalid method\"}");
    return;
  }

} catch(Exception e) {
  out.print("{\"error\":\"" + e.getMessage().replace("\"","") + "\"}");
}
%>
