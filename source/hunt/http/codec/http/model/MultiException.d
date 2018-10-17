//
//  ========================================================================
//  Copyright (c) 1995-2016 Mort Bay Consulting Pty. Ltd.
//  ------------------------------------------------------------------------
//  All rights reserved. This program and the accompanying materials
//  are made available under the terms of the Eclipse Public License v1.0
//  and Apache License v2.0 which accompanies this distribution.
//
//      The Eclipse Public License is available at
//      http://www.eclipse.org/legal/epl-v10.html
//
//      The Apache License v2.0 is available at
//      http://www.opensource.org/licenses/apache2.0.php
//
//  You may elect to redistribute this code under either of these licenses.
//  ========================================================================
//

module hunt.http.codec.http.model.MultiException;

import hunt.container;

import hunt.lang.exception;
import hunt.string;

/** 
 * Wraps multiple exceptions.
 *
 * Allows multiple exceptions to be thrown as a single exception.
 */
// 
class MultiException :Exception
{
    private List!Exception nested;

    /* ------------------------------------------------------------ */
    this()
    {
        super("Multiple exceptions");
    }

    /* ------------------------------------------------------------ */
    void add(Exception e)
    {
        if (e is null)
            throw new IllegalArgumentException("");

        if(nested is null)
        {
            // initCause(e);
            nested = new ArrayList!Exception();
        }
        // else
        //     addSuppressed(e);
        
        if (typeid(e) == typeid(MultiException))
        {
            MultiException me = cast(MultiException)e;
            // nested.addAll(me.nested);
        }
        else
            nested.add(e);
    }

    /* ------------------------------------------------------------ */
    int size()
    {
        return (nested is null)?0:nested.size();
    }
    
    /* ------------------------------------------------------------ */
    List!Exception getThrowables()
    {
        if(nested is null)
            return new EmptyList!Exception();  // Collections.emptyList();
        return nested;
    }
    
    /* ------------------------------------------------------------ */
    Exception getThrowable(int i)
    {
        return nested.get(i);
    }

    /* ------------------------------------------------------------ */
    /** Throw a multiexception.
     * If this multi exception is empty then no action is taken. If it
     * contains a single exception that is thrown, otherwise the this
     * multi exception is thrown. 
     * @exception Exception the Error or Exception if nested is 1, or the MultiException itself if nested is more than 1.
     */
    void ifExceptionThrow()
    {
        if(nested is null)
            return;
        
        switch (nested.size())
        {
          case 0:
              break;
          case 1:
              Exception th=nested.get(0);
              if (typeid(th) == typeid(Error))
                  throw cast(Error)th;
              if (typeid(th) == typeid(Exception))
                  throw cast(Exception)th;
                break;

          default:
              throw this;
        }
    }
    
    /* ------------------------------------------------------------ */
    /** Throw a Runtime exception.
     * If this multi exception is empty then no action is taken. If it
     * contains a single error or runtime exception that is thrown, otherwise the this
     * multi exception is thrown, wrapped in a runtime onException.
     * @exception Error If this exception contains exactly 1 {@link Error} 
     * @exception RuntimeException If this exception contains 1 {@link Exception} but it is not an error,
     *                             or it contains more than 1 {@link Exception} of any type.
     */
    void ifExceptionThrowRuntime()
    {
        if(nested is null)
            return;
        
        switch (nested.size())
        {
          case 0:
              break;
          case 1:
              Exception th=nested.get(0);
              if (typeid(th) == typeid(Error))
                  throw cast(Error)th;
              else if (typeid(th) == typeid(RuntimeException))
                  throw cast(RuntimeException)th;
              else
                  throw new RuntimeException(th);
          default:
              throw new RuntimeException(this);
        }
    }
    
    /* ------------------------------------------------------------ */
    /** Throw a multiexception.
     * If this multi exception is empty then no action is taken. If it
     * contains a any exceptions then this
     * multi exception is thrown. 
     * @throws MultiException the multiexception if there are nested exception
     */
    void ifExceptionThrowMulti()
    {
        if(nested is null)
            return;
        
        if (nested.size()>0)
            throw this;
    }

    /* ------------------------------------------------------------ */
    override
    string toString()
    {
        StringBuilder str = new StringBuilder();
        str.append(MultiException.stringof);
        if((nested is null) || (nested.size()<=0)) {
            str.append("[]");
        } else {
            str.append(nested.toString());
        }
        return str.toString();
    }

}
