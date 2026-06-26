<%@ page import="java.sql.*, java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/db.jsp" %>
<%
String role = (String) session.getAttribute("user_role");
if(!"admin".equals(role)) {
    out.print("{\"error\":\"unauthorized\"}");
    return;
}

try {
    String sql = "SELECT a.*, r.nombre AS rol_nombre " +
                 "FROM admin_audit a " +
                 "LEFT JOIN usuarios u ON a.admin_id = u.id::varchar " +
                 "LEFT JOIN roles r ON u.rol_id = r.id " +
                 "ORDER BY a.fecha DESC";
    PreparedStatement ps = con.prepareStatement(sql);
    ResultSet rs = ps.executeQuery();
    
    StringBuilder json = new StringBuilder("[");
    boolean first = true;
    while(rs.next()) {
        if(!first) json.append(",");
        
        String adminName = rs.getString("admin_name") != null ? rs.getString("admin_name").replace("\"", "\\\"") : "";
        String rolNombre = rs.getString("rol_nombre") != null ? rs.getString("rol_nombre").replace("\"", "\\\"") : "";

        json.append("{")
            .append("\"id\":").append(rs.getInt("id")).append(",")
            .append("\"admin_id\":\"").append(rs.getString("admin_id")).append("\",")
            .append("\"admin_name\":\"").append(adminName).append("\",")
            .append("\"rol_nombre\":\"").append(rolNombre).append("\",")
            .append("\"accion\":\"").append(rs.getString("accion")).append("\",")
            .append("\"entidad\":\"").append(rs.getString("entidad")).append("\",")
            .append("\"detalle\":\"").append(rs.getString("detalle") != null ? rs.getString("detalle").replace("\"", "\\\"") : "").append("\",")
            .append("\"fecha\":\"").append(rs.getString("fecha").substring(0, 19)).append("\"")
            .append("}");
        first = false;
    }
    json.append("]");
    
    out.print(json.toString());
} catch(Exception e) {
    out.print("{\"error\":\"" + e.getMessage().replace("\"", "\\\"") + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>
