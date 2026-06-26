<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page contentType="application/json;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ include file="../includes/db.jsp" %>
<%
try {
    String sql = "SELECT CAST(v.fecha_venta AS DATE) AS fecha_grupo, SUM(vd.precio * vd.cantidad) AS total_ingreso FROM ventas v JOIN venta_detalle vd ON v.id = vd.venta_id GROUP BY CAST(v.fecha_venta AS DATE) ORDER BY fecha_grupo ASC";
    PreparedStatement ps = con.prepareStatement(sql);
    ResultSet rs = ps.executeQuery();
    out.print("{\"status\":\"ok\"}");
} catch (Exception e) {
    out.print("{\"error\":\"" + e.getMessage() + "\"}");
}
%>
<%@ include file="../includes/db_close.jsp" %>
