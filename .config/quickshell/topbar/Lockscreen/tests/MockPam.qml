import QtQuick

QtObject {
    property string config: ""
    property bool active: false
    property bool responseRequired: false
    property string message: ""

    signal completed(int result)
    signal pamMessage

    function start() {
        active = true;
        responseRequired = true;
        return true;
    }

    function abort() {
        active = false;
        responseRequired = false;
    }

    function respond(response) {
        abort();
        completed(response === "test-success" ? MockPamResult.Success : MockPamResult.Failed);
    }
}
