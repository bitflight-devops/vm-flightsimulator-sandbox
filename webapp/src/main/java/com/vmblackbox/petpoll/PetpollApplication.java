package com.vmblackbox.petpoll;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

/**
 * Entry point for the petpoll application.
 *
 * <p>Extends {@link SpringBootServletInitializer} so the application can be deployed
 * as a WAR to an external Tomcat instance in addition to running as a standalone JAR.
 */
@SpringBootApplication
public class PetpollApplication extends SpringBootServletInitializer {

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(PetpollApplication.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(PetpollApplication.class, args);
    }
}
