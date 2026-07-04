#!/usr/bin/env bash
java -Djavax.xml.validation.SchemaFactory:http://relaxng.org/ns/structure/1.0=org.iso_relax.verifier.jaxp.validation.RELAXNGSchemaFactoryImpl -Dorg.iso_relax.verifier.VerifierFactoryLoader=com.sun.msv.verifier.jarv.FactoryLoaderImpl -jar /Users/lu/kdoffice-src/external/tarballs/odfvalidator-0.13.0-jar-with-dependencies.jar "$@"
