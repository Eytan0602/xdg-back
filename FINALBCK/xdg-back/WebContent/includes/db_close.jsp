<%
    } finally {
        if (con != null) {
            try {
                if (!con.isClosed()) {
                    try { if (!con.getAutoCommit()) con.setAutoCommit(true); } catch(Exception ignored) {}
                    java.util.concurrent.ConcurrentLinkedQueue<Connection> p = (java.util.concurrent.ConcurrentLinkedQueue<Connection>) application.getAttribute("XDG_DB_POOL");
                    if (p != null) p.offer(con);
                }
            } catch(Exception e) {}
        }
    }
} catch(Exception e) {
    out.print("{\"error\":\"DB connection failed: " + e.getMessage().replace("\"", "'") + "\"}");
}
%>
