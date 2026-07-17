<%@ page import="java.sql.*, java.util.concurrent.*, java.util.*" %>
<%
ConcurrentLinkedQueue<Connection> dbPool = (ConcurrentLinkedQueue<Connection>) application.getAttribute("XDG_DB_POOL");
if (dbPool == null) {
    dbPool = new ConcurrentLinkedQueue<Connection>();
    application.setAttribute("XDG_DB_POOL", dbPool);
}

Connection con = dbPool.poll();
try {
    if (con == null || con.isClosed()) {
        Class.forName("org.postgresql.Driver");
        con = DriverManager.getConnection(
            "jdbc:postgresql://aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require",
            "postgres.hvnplebbyprpzxygttdz",
            "QPEp35kdE6NkVjOJ"
        );
    }
    if (application.getAttribute("XDG_SCHEMA_UPDATED") == null) {
        try {
            Statement stmt = con.createStatement();
            stmt.executeUpdate("ALTER TABLE ventas ADD COLUMN IF NOT EXISTS comprador_id VARCHAR REFERENCES usuarios(id)");
            stmt.executeUpdate("ALTER TABLE ventas ADD COLUMN IF NOT EXISTS notificado BOOLEAN DEFAULT FALSE");
            stmt.executeUpdate("UPDATE ventas SET comprador_id = usuario_id WHERE comprador_id IS NULL");
            stmt.close();
            application.setAttribute("XDG_SCHEMA_UPDATED", true);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    try {
%>