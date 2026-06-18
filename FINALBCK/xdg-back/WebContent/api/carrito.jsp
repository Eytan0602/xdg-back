﻿<%@ page import="java.sql.*" %>
<%@ page contentType="application/json;charset=UTF-8" %>
<%
response.setHeader("Access-Control-Allow-Origin", "http://localhost:4321");
response.setHeader("Access-Control-Allow-Credentials", "true");
response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
response.setHeader("Access-Control-Allow-Headers", "Content-Type");
if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
    response.setStatus(200);
    return;
}
%>
<%@ include file="../includes/db.jsp" %>
<%@ include file="../includes/json-request.jsp" %>

<%
Map<String,String> jsonBody = parseJsonBody(request);
String method = request.getMethod();

try {

    if ("POST".equals(method)) {

        String user = param(request, jsonBody, "user_id");
        String juegoIdParam = param(request, jsonBody, "juego_id");

        if (user == null || juegoIdParam == null) {
            out.print("{\"error\":\"missing fields\"}");
            return;
        }

        int cantidad = Integer.parseInt(
            param(request, jsonBody, "cantidad") != null
                ? param(request, jsonBody, "cantidad")
                : "1"
        );

        int juego_id = Integer.parseInt(juegoIdParam);

        PreparedStatement cartPs = con.prepareStatement(
            "SELECT id FROM carritos WHERE usuario_id=?"
        );
        cartPs.setString(1, user);
        ResultSet cartRs = cartPs.executeQuery();

        int carritoId;

        if (cartRs.next()) {
            carritoId = cartRs.getInt("id");
        } else {
            PreparedStatement insertCartPs = con.prepareStatement(
                "INSERT INTO carritos(usuario_id) VALUES(?) RETURNING id"
            );
            insertCartPs.setString(1, user);
            ResultSet keys = insertCartPs.executeQuery();
            if (!keys.next()) {
                out.print("{\"error\":\"cannot create cart\"}");
                return;
            }
            carritoId = keys.getInt(1);
        }

        double precio;

        PreparedStatement descPs = con.prepareStatement(
            "SELECT ROUND(precio_original * (1 - porcentaje / 100.0),2) precio_final " +
            "FROM descuentos " +
            "WHERE juego_id=? AND activo=TRUE AND fecha_fin > NOW()"
        );
        descPs.setInt(1, juego_id);
        ResultSet descRs = descPs.executeQuery();

        if (descRs.next()) {
            precio = descRs.getDouble("precio_final");
        } else {
            PreparedStatement pricePs = con.prepareStatement(
                "SELECT precio FROM juegos WHERE id=?"
            );
            pricePs.setInt(1, juego_id);
            ResultSet priceRs = pricePs.executeQuery();
            if (!priceRs.next()) {
                out.print("{\"error\":\"game not found\"}");
                return;
            }
            precio = priceRs.getDouble("precio");
        }

        PreparedStatement detailPs = con.prepareStatement(
            "SELECT id, cantidad FROM carrito_detalle WHERE carrito_id=? AND juego_id=?"
        );
        detailPs.setInt(1, carritoId);
        detailPs.setInt(2, juego_id);
        ResultSet detailRs = detailPs.executeQuery();

        if (detailRs.next()) {
            int detalleId = detailRs.getInt("id");
            int actualCantidad = detailRs.getInt("cantidad");

            int nuevaCantidad;
            if (cantidad < 0) {
                nuevaCantidad = actualCantidad - Math.abs(cantidad);
            } else {
                nuevaCantidad = actualCantidad + cantidad;
            }

            if (nuevaCantidad <= 0) {
                PreparedStatement delPs = con.prepareStatement(
                    "DELETE FROM carrito_detalle WHERE id=?"
                );
                delPs.setInt(1, detalleId);
                delPs.executeUpdate();
            } else {
                PreparedStatement updatePs = con.prepareStatement(
                    "UPDATE carrito_detalle SET cantidad=? WHERE id=?"
                );
                updatePs.setInt(1, nuevaCantidad);
                updatePs.setInt(2, detalleId);
                updatePs.executeUpdate();
            }
        } else {
            if (cantidad > 0) {
                PreparedStatement insertPs = con.prepareStatement(
                    "INSERT INTO carrito_detalle (carrito_id, juego_id, cantidad, precio_unitario) " +
                    "VALUES(?,?,?,?)"
                );
                insertPs.setInt(1, carritoId);
                insertPs.setInt(2, juego_id);
                insertPs.setInt(3, cantidad);
                insertPs.setDouble(4, precio);
                insertPs.executeUpdate();
            }
        }

        out.print("{\"success\":true}");

    } else if ("GET".equals(method)) {

        String user = request.getParameter("user_id");

        if (user == null) {
            out.print("[]");
            return;
        }

        String sql =
            "SELECT cd.id, j.id as juego_id, j.titulo, j.imagen_url, j.precio, " +
            "cd.cantidad, cd.precio_unitario " +
            "FROM carritos c " +
            "JOIN carrito_detalle cd ON c.id = cd.carrito_id " +
            "JOIN juegos j ON j.id = cd.juego_id " +
            "WHERE c.usuario_id = ?";

        PreparedStatement ps = con.prepareStatement(sql);
        ps.setString(1, user);
        ResultSet rs = ps.executeQuery();

        StringBuilder json = new StringBuilder("[");
        boolean first = true;

        while (rs.next()) {
            if (!first) json.append(",");

            String titulo    = rs.getString("titulo") != null ? rs.getString("titulo").replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t") : "";
            String imagenUrl = rs.getString("imagen_url") != null ? rs.getString("imagen_url").replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t") : "";

            json.append("{")
                .append("\"detalle_id\":").append(rs.getInt("id")).append(",")
                .append("\"juego_id\":").append(rs.getInt("juego_id")).append(",")
                .append("\"titulo\":\"").append(titulo).append("\",")
                .append("\"imagen_url\":\"").append(imagenUrl).append("\",")
                .append("\"precio\":").append(rs.getDouble("precio")).append(",")
                .append("\"precio_final\":").append(rs.getDouble("precio_unitario")).append(",")
                .append("\"cantidad\":").append(rs.getInt("cantidad")).append(",")
                .append("\"porcentaje\":null,")
                .append("\"precio_original\":null")
                .append("}");

            first = false;
        }

        json.append("]");
        out.print(json.toString());

    } else if ("DELETE".equals(method)) {

        String detalleId = param(request, jsonBody, "detalle_id");

        if (detalleId == null) {
            out.print("{\"error\":\"missing detalle_id\"}");
            return;
        }

        PreparedStatement ps = con.prepareStatement(
            "DELETE FROM carrito_detalle WHERE id=?"
        );
        ps.setInt(1, Integer.parseInt(detalleId));
        int r = ps.executeUpdate();
        out.print("{\"success\":" + (r > 0) + "}");

    } else {
        out.print("{\"error\":\"invalid method\"}");
    }

} catch (Exception e) {
    out.print("{\"error\":\"" + e.getMessage().replace("\"", "") + "\"}");
}
%>