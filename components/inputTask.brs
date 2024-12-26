sub init()
    ' When the task is RUN, call "listenInput"
    m.top.functionName = "listenInput"
end sub

function listenInput()
    port = createObject("roMessagePort")
    inputObj = createObject("roInput")
    inputObj.setMessagePort(port)

    while true
        msg = port.waitMessage(500) ' wait up to 500ms (or any interval) for roInputEvent
        if type(msg) = "roInputEvent"
            print "INPUT EVENT DETECTED"

            if msg.isInput()
                data = msg.getInfo()
                for each k in data
                    print k; ": "; data[k]
                end for

                ' If there's deep link info
                if data.doesExist("contentID") and data.doesExist("mediaType")
                    newData = {
                        id: data.contentID
                        type: data.mediaType
                    }
                    print "Got roInput deep link => "; newData
                    m.top.inputData = newData
                end if
            end if
        else if msg = invalid
            ' no input event, loop continues
        end if
    end while
end function
