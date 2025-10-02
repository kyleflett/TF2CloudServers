package com.SwiftyServers;

public class Main {
    public static void main(String[] args) {
        System.out.println("Launching Server on Linode...");
        LinodeApiHandler linodeApiHandler = new LinodeApiHandler();
        String responseBody;
        try {
            responseBody = linodeApiHandler.createInstance("1");
            System.out.println(responseBody);
            System.out.println("Server launched successfully!");
        } catch (Exception e) {
            e.printStackTrace();
            System.out.println("Server failed to launch.");
        }
    }
}