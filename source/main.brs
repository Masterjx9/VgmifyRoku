sub main()
    screen = createObject("roSGScreen")
    port   = createObject("roMessagePort")
    screen.setMessagePort(port)

    ' Create the scene for Vgmify Radio
    scene = screen.CreateScene("VgmifyRadioScene")
    screen.Show()

    ' Create roInput and set its message port
    inputObject = CreateObject("roInput")
    inputObject.SetMessagePort(port)

    ' Main message loop
    while true
        msg = wait(0, port)
        if msg <> invalid
            if type(msg) = "roSGScreenEvent"
                if msg.isScreenClosed()
                    print "Main: Screen closed"
                    return
                end if
            else if type(msg) = "roInputEvent"
                print "Received roInputEvent."
                if msg.isInput()
                    inputData = msg.GetInfo()
                    print "Input Data: "; inputData
                end if
            end if
        end if
    end while
end sub
