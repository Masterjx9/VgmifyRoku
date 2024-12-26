sub init()
    m.top.functionName = "doApiFetch"
end sub


sub getcontent()
    content = createObject("roSGNode", "ContentNode")

    contentxml = createObject("roXMLElement")

    readInternet = createObject("roUrlTransfer")
  end sub
  
sub doHttpPost()
    url  = m.top.postUrl
    body = m.top.postBody

    if url = invalid or url = ""
        print "FetchMusicTask: No URL provided"
        return
    end if

    print "FetchMusicTask: Creating roUrlTransfer (on Task thread)..."
    xfer = createObject("roUrlTransfer")
end sub


sub doApiFetch()
    m.top.scene.findNode("AudioCurrent").text = "Loading..."
    m.top.scene.findNode("AudioDuration").text = "--:--"
    url = m.top.apiUrl
    if url = invalid or url = ""
        print "MyFetchTask: no apiUrl provided"
        return
    end if

    print "MyFetchTask: creating roUrlTransfer (ASYNC) => "; url

    xfer = createObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
    xfer.InitClientCertificates()
    xfer.EnablePeerVerification(false)
    xfer.EnableHostVerification(false)

    xfer.setURL(url)
    xfer.SetRequest("POST")

    xferPort = createObject("roMessagePort")
    xfer.setMessagePort(xferPort)
    xfer.AddHeader("Content-Type", "application/json")
    nooptions = {
        "option": invalid
    }
    nooptionsJson = FormatJson(nooptions)
    xfer.AsyncPostFromString(nooptionsJson)
    
    print xfer.GetRequest()

    while true
        evt = wait(0, xferPort) ' Wait for the event
        if evt <> invalid
            if type(evt) = "roUrlEvent"
                code = evt.GetResponseCode()
                print "Async response code => "; code
                print evt.GetString()

                if code = 200
                    respBody = evt.GetString()
                    if respBody = invalid
                        print "MyFetchTask: invalid or empty response"
                    else
                        m.top.response = respBody
                        print "MyFetchTask: got response of length="; len(respBody)
                        print "Actual response => "; left(respBody, 30) + "..."
                        
                        print "Actual response => "; respBody

                        ' 1) Parse the JSON
                        data = ParseJson(respBody)
                        if data = invalid
                            print "Error: Invalid JSON"
                            return
                        end if

                        ' 2) Retrieve the 'artists' array
                        artistsList = data["artists"]
                        if artistsList = invalid or artistsList.count() = 0
                            print "No artists found in JSON"
                            m.top.scene.findNode("Author").text = "Unknown Artist"
                            return
                        end if

                        ' 3) Join the array items with commas and set it to the label
                        joinedArtists = artistsList.join(", ")
                        print m.top
                        print m.top.scene
                        m.top.scene.findNode("Author").text = joinedArtists

                        m.top.scene.findNode("Title").text = data["name"]
                        m.top.scene.findNode("AudioDuration").text = data["time"]

                    end if
                else
                    print "MyFetchTask: Non-200 => "; code
                    print "Failure reason => "; evt.GetFailureReason()
                end if

                exit while  ' done waiting
            end if
        else
            print "MyFetchTask: Timed out waiting for roUrlEvent..."
            exit while
        end if
    end while
end sub
