module test.codec.http2;

import HttpClientTest;


void main(string[] args) {

    HttpClientTest test = new HttpClientTest();
    // test.testGet();
    // test.testGetHttps();
    // test.testAsynchronousGet();
    // test.testPost();
    test.testFormPost();

}

