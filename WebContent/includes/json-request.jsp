<%@ page import="java.io.*, java.util.*" %>
<%!
    private Map<String,String> parseJsonBody(javax.servlet.http.HttpServletRequest request) throws IOException {
        request.setCharacterEncoding("UTF-8");
        
        String contentType = request.getContentType();
        if(contentType == null || !contentType.toLowerCase().contains("application/json")) {
            return new HashMap<String,String>();
        }

        java.io.InputStream is = request.getInputStream();
        java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[1024];
        int bytesRead;
        while ((bytesRead = is.read(chunk)) != -1) {
            buffer.write(chunk, 0, bytesRead);
        }
        String json = buffer.toString("UTF-8").trim();

        Map<String,String> values = new HashMap<String,String>();

        if(json.startsWith("{") && json.endsWith("}")) {
            json = json.substring(1, json.length() - 1).trim();
            if(!json.isEmpty()) {
                String[] pairs = json.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
                for(String pair : pairs) {
                    String[] parts = pair.split(":(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", 2);
                    if(parts.length == 2) {
                        String key = stripQuotes(parts[0].trim());
                        String value = stripQuotes(parts[1].trim());
                        values.put(key, value);
                    }
                }
            }
        }

        return values;
    }

    private String stripQuotes(String text) {
        if(text == null) {
            return null;
        }
        text = text.trim();
        if(text.startsWith("\"") && text.endsWith("\"") && text.length() >= 2) {
            text = text.substring(1, text.length() - 1);
        }
        return text;
    }

    private String param(javax.servlet.http.HttpServletRequest request, Map<String,String> jsonBody, String name) {
        String value = jsonBody.get(name);
        return value != null ? value : request.getParameter(name);
    }
%>