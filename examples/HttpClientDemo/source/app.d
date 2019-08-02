module test.codec.http2;

import HttpClientTest;

import std.stdio;

void main(string[] args) {

    HttpClientTest test = new HttpClientTest();
    // test.testGet();
    // test.testGetHttps();
    // test.testAsynchronousGet();
    test.testPost();
    // test.testFormPost();

    // writeln(HUNT_LOGO);


}

// enum string HUNT_LOGO = `
// `;
