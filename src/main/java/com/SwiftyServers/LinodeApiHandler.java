package com.SwiftyServers;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class LinodeApiHandler {
    private static final String LINODE_API_URL = "https://api.linode.com/v4/linode/instances";
    private static final String API_KEY = "";

    public String createInstance(String serverId) throws Exception {
        String jsonPayload = buildJsonPayload(serverId);
        System.out.println("Payload: " + jsonPayload);

        URL url = new URL(LINODE_API_URL);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setRequestProperty("Authorization", "Bearer " + API_KEY);
        connection.setDoOutput(true);

        try (OutputStream os = connection.getOutputStream()) {
            os.write(jsonPayload.getBytes());
            os.flush();
        }
        int responseCode;
        try {
            responseCode = connection.getResponseCode();
        } catch (Exception e) {
            responseCode = 400;
            System.out.println("Failed to connect to Linode API: " + e.getMessage());
        }

        // Read response body - use errorStream for error responses, inputStream for success
        StringBuilder response = new StringBuilder();
        BufferedReader reader = null;

        try {
            if (responseCode >= 400) {
                // Error response - read from error stream
                reader = new BufferedReader(new InputStreamReader(connection.getErrorStream()));
            } else {
                // Success response - read from input stream
                reader = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            }

            String inputLine;
            while ((inputLine = reader.readLine()) != null) {
                response.append(inputLine);
            }
        } finally {
            if (reader != null) {
                reader.close();
            }
        }

        System.out.println("Response Code: " + responseCode);
        System.out.println("Response Body: " + response.toString());

        if (responseCode != HttpURLConnection.HTTP_OK &&
                responseCode != HttpURLConnection.HTTP_CREATED &&
                responseCode != HttpURLConnection.HTTP_ACCEPTED) {

            // Try to extract error details from response
            String errorDetails = response.toString();
            try {
                JsonObject errorJson = JsonParser.parseString(errorDetails).getAsJsonObject();
                if (errorJson.has("errors")) {
                    errorDetails = "API Errors: " + errorJson.get("errors").toString();
                } else if (errorJson.has("message")) {
                    errorDetails = "API Message: " + errorJson.get("message").getAsString();
                }
            } catch (Exception e) {
                // If JSON parsing fails, use raw response
                System.out.println("Could not parse error response as JSON: " + e.getMessage());
            }

            throw new Exception("Failed to create instance. HTTP " + responseCode + ". Details: " + errorDetails);
        }

        return response.toString();
    }

    public String getInstanceIp(String instanceId) throws Exception {
        String instanceUrl = LINODE_API_URL + "/" + instanceId;
        while (true) {
            URL url = new URL(instanceUrl);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("Authorization", "Bearer " + API_KEY);

            int responseCode = connection.getResponseCode();
            if (responseCode != HttpURLConnection.HTTP_OK) {
                throw new Exception("Failed to get instance details, response code: " + responseCode);
            }

            StringBuilder response;
            try (BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()))) {
                String inputLine;
                response = new StringBuilder();
                while ((inputLine = in.readLine()) != null) {
                    response.append(inputLine);
                }
            }

            JsonObject jsonResponse = JsonParser.parseString(response.toString()).getAsJsonObject();
            JsonObject instance = jsonResponse.getAsJsonObject("instance");
            String mainIp = instance.get("main_ip").getAsString();

            if (!"0.0.0.0".equals(mainIp)) {
                System.out.println("Instance IP Ready: " + mainIp);
                return mainIp;
            }

            System.out.println("Waiting for IP to be ready...");
            Thread.sleep(5000); // Wait for 5 seconds before checking again
        }
    }

    private String buildJsonPayload(String serverId) {
        int stackscript_id = 123456; // Replace with your actual StackScript ID
        JsonObject payload = new JsonObject();
        payload.addProperty("region", "us-ord");
        payload.addProperty("type", "g6-dedicated-2"); //USE DEDICATED ONLY, NOT SHARED
        payload.addProperty("image", "linode/ubuntu22.04");
        payload.addProperty("stackscript_id", stackscript_id);
        payload.addProperty("root_pass", ""); // Change this to a strong password or generate dynamically
        payload.addProperty("label", "TF2-Server-" + serverId);
        payload.addProperty("backups_enabled", false);

        return payload.toString();
    }
}