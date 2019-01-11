module test.codec.http2.hpack.TestHuffman;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;

// import hunt.util.Test;

import hunt.http.codec.http.hpack.Huffman;

import hunt.Assert;
import hunt.Exceptions;
import hunt.util.TypeUtils;

import hunt.logging;

import std.conv;
import std.string;

class TestHuffman
{
    // dfmt off
    string[][] tests =
        [
            ["D.4.1","f1e3c2e5f23a6ba0ab90f4ff","www.example.com"],
            ["D.4.2","a8eb10649cbf","no-cache"],
            ["D.6.1k","6402","302"],
            ["D.6.1v","aec3771a4b","private"],
            ["D.6.1d","d07abe941054d444a8200595040b8166e082a62d1bff","Mon, 21 Oct 2013 20:13:21 GMT"],
            ["D.6.1l","9d29ad171863c78f0b97c8e9ae82ae43d3","https://www.example.com"],
            ["D.6.2te","640cff","303"],
        ];
    // dfmt on
    
    
    void testDecode()
    {
        foreach (string[] test; tests)
        {
            byte[] encoded=TypeUtils.fromHexString(test[1]);
            string decoded=Huffman.decode(ByteBuffer.wrap(encoded));
            Assert.assertEquals(test[0],test[2],decoded);
        }
    }
    
    
    void testDecodeTrailingFF()
    {
        foreach (string[] test; tests)
        {
            byte[] encoded=TypeUtils.fromHexString(test[1]~"FF");
            string decoded=Huffman.decode(ByteBuffer.wrap(encoded));
            Assert.assertEquals(test[0],test[2],decoded);
        }
    }
    
    
    void testEncode()
    {
        foreach (string[] test; tests)
        {
            ByteBuffer buf = BufferUtils.allocate(1024);
            int pos=BufferUtils.flipToFill(buf);
            Huffman.encode(buf,test[2]);
            BufferUtils.flipToFlush(buf,pos);
            string encoded=TypeUtils.toHexString(BufferUtils.toArray(buf)).toLower();
            Assert.assertEquals(test[0],test[1],encoded);
            Assert.assertEquals(test[1].length/2, Huffman.octetsNeeded(test[2]));
        }
    }

    
    void testEncode8859Only()
    {
        char[] bad = [cast(char)128,cast(char)0,cast(char)-1,' '-1];
        for (int i=0;i<bad.length;i++)
        {
            string s="bad '"~bad[i]~"'";
            
            try
            {
                Huffman.octetsNeeded(s);
                Assert.fail("i="~to!string(i));
            }
            catch(IllegalArgumentException e)
            {
            }
            
            try
            {
                Huffman.encode(BufferUtils.allocate(32),s);
                Assert.fail("i="~to!string(i));
            }
            catch(IllegalArgumentException e)
            {
            }
        }
    }
    
    
}
