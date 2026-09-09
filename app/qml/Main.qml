// The Basecamp module's interface.
//
// Started from spel-client-gen --target logos-module, then rewritten. The generated scaffold gave
// every instruction a column of identical inputs labelled "value" and printed fetched accounts as
// raw key/value pairs — correct, and unreadable. What is on screen here is the same set of calls,
// laid out so a reviewer can tell what a panel is for without reading the IDL first.
//
// `scripts/build-basecamp.sh --regen` overwrites this file; re-apply the hardening if you run it.
// Two properties are enforced by scripts and must survive any edit:
//   · check-basecamp-privacy.sh — no witness input, and no field naming another member.
//   · check-basecamp-contract.sh — the backend is resolved from either host, with no broken binding.
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property int currentPageIndex: 0

    // ── Palette and metrics ──────────────────────────────────────────────
    // Accent and text come from the Logos palette (#8B9A6E, #F7F2EB, #EAE2D6, #EEEEEE) rather than
    // the violet this started with. Two notes worth keeping, because both were measured rather than
    // guessed by rendering the components offscreen with each candidate:
    //   · the sage #8B9A6E sits in the same family as colSuccess, so an information pill in sage
    //     and a "executed" pill in green stop being tellable apart. The accent stays cream.
    //   · #F7F2EB as the accent reads as plain white at button size; #EAE2D6 still reads as cream.
    //     So: #EAE2D6 accents, #F7F2EB text.
    readonly property color colBg:      "#0e1016"
    readonly property color colSurface: "#161923"
    readonly property color colRaised:  "#1c2030"
    readonly property color colSidebar: "#12141d"
    readonly property color colBorder:  "#262b3b"
    readonly property color colPrimary: "#EAE2D6"
    readonly property color colSuccess: "#3ecf8e"
    readonly property color colError:   "#e05252"
    readonly property color colWarn:    "#e0a352"
    readonly property color colText:    "#F7F2EB"
    // Derived, not picked: the same hue as the text, desaturated and dimmed. A hand-picked grey
    // went cold against warm text, and would have to be re-picked by hand every time colText moved.
    readonly property color colMuted:   Qt.hsla(colText.hslHue, colText.hslSaturation * 0.35, 0.56, 1)
    readonly property int    radius:    12
    readonly property int    pad:       20
    readonly property string mono:      "Menlo, Monaco, Consolas, monospace"

    // ── Where the backend comes from ─────────────────────────────────────
    //
    // This QML runs in two different processes. Standalone (PrivateMultisigApp, and the module
    // loaded in-process) it is handed `ctxBackend` as a context property. Inside Logos Basecamp it
    // is loaded by the *main* process, while the plugin's C++ lives in a `ui-host` child — there,
    // the object is reached through Basecamp's `logos` registry, exactly as its own
    // package_manager_ui does. Resolving both here means every binding below can just say
    // `backend`, and neither host needs its own copy of this file.
    //
    // `logos.module()` yields a QtRemoteObjects replica, so a call is a message and a property read
    // is a cached value: nothing below may assume a result is ready on the next line.
    readonly property var backend: (typeof ctxBackend !== "undefined" && ctxBackend)
        ? ctxBackend
        : ((typeof logos !== "undefined" && logos) ? logos.module("private_multisig") : null)

    // Losing the backend is the one failure that makes every panel silently inert, so it is said
    // out loud rather than left to the log.
    readonly property bool backendReady: backend !== null && backend !== undefined

    Component.onCompleted: {
        if (!root.backendReady)
            console.warn("private_multisig: no backend — neither a ctxBackend context property nor "
                         + "logos.module(\"private_multisig\") resolved. Every panel will be inert.")
        else
            console.log("private_multisig: backend resolved via "
                        + ((typeof ctxBackend !== "undefined" && ctxBackend) ? "context property"
                                                                            : "logos.module()"))
    }

    // ── Conversions ──────────────────────────────────────────────────────

    // A ProgramId on the wire is [u32; 8], little-endian per four bytes — the same words
    // `verify-onchain.sh` and the FFI use. Everything a person actually holds writes it as the
    // 64-character ImageID hex, so accept that (and a plain list of eight numbers), and refuse
    // anything else rather than sending a malformed list the FFI will reject with a worse message.
    function programIdWords(text) {
        var t = (text || "").trim().replace(/^0x/i, "").replace(/\s+/g, "")
        if (/^[0-9a-fA-F]{64}$/.test(t)) {
            var out = []
            for (var i = 0; i < 8; i++) {
                var b = t.substr(i * 8, 8)
                out.push(parseInt(b.substr(6, 2) + b.substr(4, 2) + b.substr(2, 2) + b.substr(0, 2), 16))
            }
            return out
        }
        var parts = (text || "").split(/[^0-9]+/).filter(function (s) { return s.length > 0 })
        if (parts.length !== 8) return []
        return parts.map(function (s) { return parseInt(s, 10) })
    }

    // The inverse, for display: eight words back to the ImageID a reader can compare against
    // docs/DEPLOYMENT.md by eye.
    function wordsToHex(words) {
        if (!words || words.length !== 8) return ""
        var out = ""
        for (var i = 0; i < 8; i++) {
            var w = words[i] >>> 0
            for (var b = 0; b < 4; b++)
                out += ("0" + ((w >>> (b * 8)) & 0xff).toString(16)).slice(-2)
        }
        return out
    }

    // The decoder renders every 32-byte field the way an address is written — base58 with a
    // `Public/` prefix — including the ones that are not addresses at all. A config hash shown that
    // way cannot be compared with the hex the operator typed to fetch it, or with DEPLOYMENT.md.
    // So hashes are converted back; anything that is not 32 base58 bytes is left exactly as it came.
    function base58ToHex(value) {
        var s = String(value === undefined || value === null ? "" : value)
                    .replace(/^(Public|Private)\//, "")
        if (s.length === 0) return ""
        var alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        var bytes = []
        for (var i = 0; i < s.length; i++) {
            var carry = alphabet.indexOf(s.charAt(i))
            if (carry < 0) return ""
            for (var j = 0; j < bytes.length; j++) {
                carry += bytes[j] * 58
                bytes[j] = carry & 0xff
                carry = carry >>> 8
            }
            while (carry > 0) { bytes.push(carry & 0xff); carry = carry >>> 8 }
        }
        for (var k = 0; k < s.length && s.charAt(k) === "1"; k++) bytes.push(0)
        if (bytes.length !== 32) return ""
        bytes.reverse()
        var hex = ""
        for (var b = 0; b < 32; b++) hex += ("0" + bytes[b].toString(16)).slice(-2)
        return hex
    }

    // A hash for display: hex when it is one, otherwise whatever the decoder gave.
    function hashText(v) {
        var hex = root.base58ToHex(v)
        return hex.length > 0 ? hex : root.asText(v)
    }

    function asText(v) {
        if (v === undefined || v === null) return ""
        if (Array.isArray(v)) return v.join(", ")
        return String(v)
    }

    function cfg() { return root.backendReady ? backend.config : ({}) }
    function prop() { return root.backendReady ? backend.proposal : ({}) }
    function fetchError(which) {
        return root.backendReady ? (backend.fetchErrors[which] || "") : "backend unavailable"
    }

    // ── Reusable pieces ──────────────────────────────────────────────────

    component Card: Rectangle {
        id: card
        default property alias content: inner.data
        property string title: ""
        Layout.fillWidth: true
        Layout.leftMargin: 28
        Layout.rightMargin: 28
        // A card that runs the full width of a wide pane makes every line hard to track back to
        // the next one. Cap the measure and keep it left-aligned with the page title.
        Layout.maximumWidth: 980
        Layout.alignment: Qt.AlignLeft
        color: root.colSurface
        radius: root.radius
        border.width: 1
        border.color: root.colBorder
        implicitHeight: col.implicitHeight + 2 * root.pad
        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            spacing: 12
            Text {
                visible: card.title.length > 0
                text: card.title
                color: root.colText
                font.pixelSize: 14
                font.bold: true
            }
            ColumnLayout {
                id: inner
                Layout.fillWidth: true
                spacing: 12
            }
        }
    }

    component Field: ColumnLayout {
        id: field
        property string label: ""
        property string hint: ""
        property alias text: input.text
        property alias placeholder: input.placeholderText
        signal committed(string value)
        Layout.fillWidth: true
        spacing: 5
        Text {
            text: field.label
            color: root.colMuted
            font.pixelSize: 10
            font.letterSpacing: 0.6
            font.bold: true
        }
        TextField {
            id: input
            Layout.fillWidth: true
            color: root.colText
            placeholderTextColor: Qt.darker(root.colMuted, 1.35)
            font.family: root.mono
            font.pixelSize: 12
            selectByMouse: true
            leftPadding: 10
            rightPadding: 10
            onEditingFinished: field.committed(text.trim())
            background: Rectangle {
                color: root.colRaised
                border.color: input.activeFocus ? root.colPrimary : root.colBorder
                border.width: 1
                radius: root.radius / 2
                implicitHeight: 34
            }
        }
        Text {
            visible: field.hint.length > 0
            text: field.hint
            color: Qt.darker(root.colMuted, 1.25)
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    component CopyButton: Button {
        id: copyBtn
        property string value: ""
        property bool copied: false
        implicitWidth: 26
        implicitHeight: 26
        Layout.alignment: Qt.AlignTop
        onClicked: { clipHelper.copyText(copyBtn.value); copyBtn.copied = true; resetTimer.restart() }
        Timer { id: resetTimer; interval: 1400; onTriggered: copyBtn.copied = false }
        background: Item {}
        contentItem: Text {
            text: copyBtn.copied ? "✓" : "⧉"
            color: copyBtn.copied ? root.colSuccess : root.colMuted
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component KeyRow: RowLayout {
        id: keyRow
        property string k: ""
        property string v: ""
        property bool mono: true
        property bool copyable: true
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: keyRow.k
            color: root.colMuted
            font.pixelSize: 12
            Layout.preferredWidth: 155
            Layout.alignment: Qt.AlignTop
        }
        Text {
            text: keyRow.v
            color: root.colText
            font.pixelSize: 12
            font.family: keyRow.mono ? root.mono : Qt.application.font.family
            wrapMode: Text.WrapAnywhere
            Layout.fillWidth: true
        }
        CopyButton {
            visible: keyRow.copyable && keyRow.v.length > 0
            value: keyRow.v
        }
    }

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property color tone: root.colMuted
        implicitWidth: pillText.implicitWidth + 18
        implicitHeight: 22
        radius: 11
        color: Qt.rgba(pill.tone.r, pill.tone.g, pill.tone.b, 0.15)
        border.width: 1
        border.color: Qt.rgba(pill.tone.r, pill.tone.g, pill.tone.b, 0.45)
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.tone
            font.pixelSize: 11
            font.bold: true
        }
    }

    component PrimaryButton: Button {
        id: primary
        property bool working: false
        implicitHeight: 34
        implicitWidth: Math.max(112, primaryLabel.implicitWidth + 32)
        enabled: !primary.working && root.backendReady
        background: Rectangle {
            radius: root.radius / 2
            color: primary.down ? Qt.darker(root.colPrimary, 1.25) : root.colPrimary
            opacity: primary.enabled ? 1.0 : 0.4
        }
        contentItem: Text {
            id: primaryLabel
            text: primary.working ? "working…" : primary.text
            // White on a violet fill was legible; white on a cream fill is not. Derived from the
            // fill rather than hardcoded, so changing colPrimary cannot silently make the primary
            // action unreadable — which is exactly what changing it once already did.
            color: root.colPrimary.hslLightness > 0.6 ? root.colBg : "#ffffff"
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component GhostButton: Button {
        id: ghost
        implicitHeight: 30
        implicitWidth: Math.max(84, ghostLabel.implicitWidth + 28)
        enabled: root.backendReady
        background: Rectangle {
            radius: root.radius / 2
            color: ghost.down ? root.colRaised : "transparent"
            border.color: root.colBorder
            border.width: 1
            opacity: ghost.enabled ? 1.0 : 0.4
        }
        contentItem: Text {
            id: ghostLabel
            text: ghost.text
            color: root.colText
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component PageHeader: ColumnLayout {
        id: header
        property string title: ""
        property string subtitle: ""
        Layout.fillWidth: true
        Layout.leftMargin: 28
        Layout.rightMargin: 28
        Layout.maximumWidth: 980
        Layout.alignment: Qt.AlignLeft
        spacing: 5
        Text {
            text: header.title
            color: root.colText
            font.pixelSize: 20
            font.bold: true
        }
        Text {
            visible: header.subtitle.length > 0
            text: header.subtitle
            color: root.colMuted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    component Note: Text {
        Layout.fillWidth: true
        color: root.colMuted
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    component EmptyState: Text {
        id: empty
        property string message: ""
        property bool isError: false
        Layout.fillWidth: true
        text: (empty.isError ? "✗  " : "") + empty.message
        color: empty.isError ? root.colError : root.colMuted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // Clipboard, without pulling in a platform dependency Basecamp may not ship.
    TextEdit {
        id: clipHelper
        visible: false
        function copyText(t) { text = t; selectAll(); copy(); }
    }

    // ── Frame ────────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: root.colBg

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── Sidebar ──────────────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 216
                Layout.fillHeight: true
                color: root.colSidebar

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        Layout.leftMargin: 18
                        Layout.rightMargin: 14
                        Text {
                            text: "Private Multisig"
                            color: root.colText
                            font.pixelSize: 15
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Row {
                            spacing: 4
                            visible: root.backendReady && backend.busy
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 5; height: 5; radius: 2.5
                                    color: root.colPrimary
                                    SequentialAnimation on opacity {
                                        running: root.backendReady && backend.busy
                                        loops: Animation.Infinite
                                        PauseAnimation  { duration: index * 180 }
                                        NumberAnimation { to: 1.0;  duration: 220 }
                                        NumberAnimation { to: 0.25; duration: 220 }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.colBorder }

                    ListView {
                        id: nav
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 8
                        interactive: false
                        model: ListModel {
                            ListElement { section: "ON CHAIN"; name: "";                page: -1 }
                            ListElement { section: "";         name: "Config";          page:  0 }
                            ListElement { section: "";         name: "Proposal";        page:  1 }
                            ListElement { section: "SUBMIT";   name: "";                page: -1 }
                            ListElement { section: "";         name: "Create Multisig"; page:  2 }
                            ListElement { section: "";         name: "Create Proposal"; page:  3 }
                            ListElement { section: "";         name: "Approve";         page:  4 }
                            ListElement { section: "";         name: "Execute";         page:  5 }
                            ListElement { section: "WALLET";   name: "";                page: -1 }
                            ListElement { section: "";         name: "Accounts";        page:  6 }
                            ListElement { section: "";         name: "Settings";        page:  7 }
                        }
                        delegate: Item {
                            width: nav.width
                            height: page < 0 ? 30 : 34

                            Text {
                                visible: page < 0
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: section
                                color: Qt.darker(root.colMuted, 1.4)
                                font.pixelSize: 10
                                font.letterSpacing: 1.2
                                font.bold: true
                            }

                            Rectangle {
                                visible: page >= 0
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                radius: root.radius / 2
                                color: root.currentPageIndex === page
                                       ? root.colRaised
                                       : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                                Rectangle {
                                    visible: root.currentPageIndex === page
                                    width: 3; height: 16; radius: 1.5
                                    color: root.colPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    text: name
                                    color: root.currentPageIndex === page ? root.colText : root.colMuted
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentPageIndex = page
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.colBorder }

                    Text {
                        Layout.fillWidth: true
                        Layout.margins: 14
                        text: root.backendReady ? (backend.sequencerUrl.length > 0 ? backend.sequencerUrl
                                                                                   : "no sequencer set")
                                                : "backend unavailable"
                        color: root.backendReady ? root.colMuted : root.colError
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.colBorder }

            // ── Pages ────────────────────────────────────────────────────
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPageIndex

                // ── 0. Config ───────────────────────────────────────────
                ScrollView {
                    id: configPage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: configPage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Config"
                            subtitle: "The multisig's parameters, read from its own account on chain. The "
                                      + "threshold, the member set and the verifier are all committed in the "
                                      + "address, so an account at this address cannot hold different ones."
                        }

                        Card {
                            title: "Look up a multisig"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Field {
                                    id: configHashField
                                    label: "CONFIG HASH"
                                    placeholder: "64 hex characters"
                                    hint: "From docs/DEPLOYMENT.md, or printed by deploy-testnet.sh."
                                }
                                PrimaryButton {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 19
                                    text: "Fetch"
                                    working: root.backendReady && backend.busy
                                    onClicked: backend.fetchConfig(configHashField.text.trim())
                                }
                            }
                        }

                        Card {
                            title: "On chain"

                            EmptyState {
                                visible: Object.keys(root.cfg()).length === 0
                                isError: root.fetchError("config").length > 0
                                message: root.fetchError("config").length > 0
                                         ? root.fetchError("config")
                                         : "Nothing fetched yet — enter a config hash above and press Fetch."
                            }

                            RowLayout {
                                visible: Object.keys(root.cfg()).length > 0
                                Layout.fillWidth: true
                                spacing: 8
                                Pill {
                                    tone: root.colPrimary
                                    label: root.asText(root.cfg()["m"]) + " of " + root.asText(root.cfg()["n"])
                                           + " required"
                                }
                                Pill {
                                    tone: root.colMuted
                                    label: "state v" + root.asText(root.cfg()["version"])
                                }
                                Item { Layout.fillWidth: true }
                            }

                            KeyRow {
                                visible: Object.keys(root.cfg()).length > 0
                                k: "Member root"
                                v: root.hashText(root.cfg()["member_root"])
                            }
                            KeyRow {
                                visible: Object.keys(root.cfg()).length > 0
                                k: "Multisig id"
                                v: root.hashText(root.cfg()["multisig_id"])
                            }
                            KeyRow {
                                visible: Object.keys(root.cfg()).length > 0
                                k: "Membership verifier"
                                v: root.wordsToHex(root.cfg()["membership_program_id"])
                            }
                            KeyRow {
                                visible: Object.keys(root.cfg()).length > 0
                                k: "Proposals created"
                                mono: false
                                copyable: false
                                v: root.asText(root.cfg()["proposal_count"])
                            }
                            Note {
                                visible: Object.keys(root.cfg()).length > 0
                                text: "There is no member list here, and no field that could hold one. Membership "
                                      + "is proven against the root above, in zero knowledge."
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }

                // ── 1. Proposal ─────────────────────────────────────────
                ScrollView {
                    id: proposalPage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: proposalPage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Proposal"
                            subtitle: "What was proposed, how many approvals it has, and whether it ran."
                        }

                        Card {
                            title: "Look up a proposal"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Field {
                                    id: proposalSeedField
                                    label: "PROPOSAL SEED"
                                    placeholder: "64 hex characters"
                                    hint: "From docs/DEPLOYMENT.md, or printed when the proposal was created."
                                }
                                PrimaryButton {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 19
                                    text: "Fetch"
                                    working: root.backendReady && backend.busy
                                    onClicked: backend.fetchProposal(proposalSeedField.text.trim())
                                }
                            }
                        }

                        Card {
                            title: "On chain"

                            EmptyState {
                                visible: Object.keys(root.prop()).length === 0
                                isError: root.fetchError("proposal").length > 0
                                message: root.fetchError("proposal").length > 0
                                         ? root.fetchError("proposal")
                                         : "Nothing fetched yet — enter a proposal seed above and press Fetch."
                            }

                            RowLayout {
                                visible: Object.keys(root.prop()).length > 0
                                Layout.fillWidth: true
                                spacing: 8
                                Pill {
                                    tone: root.colPrimary
                                    label: (root.prop()["nullifiers"] || []).length + " approval(s)"
                                }
                                Pill {
                                    tone: root.prop()["executed"] ? root.colSuccess : root.colWarn
                                    label: root.prop()["executed"] ? "executed" : "pending"
                                }
                                Item { Layout.fillWidth: true }
                            }

                            KeyRow {
                                visible: Object.keys(root.prop()).length > 0 && root.prop()["action"] !== undefined
                                k: "Sends"
                                mono: false
                                copyable: false
                                v: {
                                    var a = root.prop()["action"]
                                    var t = a ? a["TreasuryTransfer"] : null
                                    return t ? (t["amount"] + " to " + t["recipient"]) : ""
                                }
                            }
                            KeyRow {
                                visible: Object.keys(root.prop()).length > 0
                                k: "Belongs to config"
                                v: root.hashText(root.prop()["config_hash"])
                            }
                            KeyRow {
                                visible: Object.keys(root.prop()).length > 0
                                k: "Proposal id"
                                v: root.hashText(root.prop()["proposal_id"])
                            }

                            Text {
                                visible: Object.keys(root.prop()).length > 0
                                text: "Nullifiers"
                                color: root.colMuted
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 0.6
                                Layout.topMargin: 4
                            }
                            Repeater {
                                model: root.prop()["nullifiers"] || []
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Text {
                                        text: "#" + (index + 1)
                                        color: root.colMuted
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 30
                                        Layout.alignment: Qt.AlignTop
                                    }
                                    Text {
                                        text: root.hashText(modelData)
                                        color: root.colText
                                        font.pixelSize: 12
                                        font.family: root.mono
                                        wrapMode: Text.WrapAnywhere
                                        Layout.fillWidth: true
                                    }
                                    CopyButton { value: root.hashText(modelData) }
                                }
                            }
                            Note {
                                visible: Object.keys(root.prop()).length > 0
                                text: "One per approval, and nothing else. They name no one, and the same member's "
                                      + "nullifier on another proposal cannot be linked to these."
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }

                // ── 2. Create Multisig ──────────────────────────────────
                ScrollView {
                    id: createMultisigPage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: createMultisigPage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Create Multisig"
                            subtitle: "Writes the config account. Its address is the hash of these values, so none "
                                      + "of them can change afterwards — a different threshold is a different "
                                      + "multisig, at a different address."
                        }

                        Card {
                            Field {
                                id: cmCreator
                                label: "CREATOR ACCOUNT"
                                placeholder: "Public/…"
                                hint: "Pays for the transaction. The Accounts page lists the ones this wallet holds."
                            }
                            Field {
                                id: cmConfigHash
                                label: "CONFIG HASH"
                                placeholder: "64 hex characters"
                                hint: "The hash of the values below; the SDK prints it."
                            }
                            Field {
                                id: cmMemberRoot
                                label: "MEMBER ROOT"
                                placeholder: "64 hex characters"
                                hint: "Merkle root over the members' nullifier public keys. The leaves are never published."
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Field { id: cmM; label: "THRESHOLD M"; placeholder: "2" }
                                Field { id: cmN; label: "MEMBERS N";   placeholder: "3" }
                            }
                            Field {
                                id: cmMultisigId
                                label: "MULTISIG ID"
                                placeholder: "64 hex characters"
                                hint: "Any value you choose; it distinguishes multisigs with identical membership."
                            }
                            Field {
                                id: cmVerifier
                                label: "MEMBERSHIP VERIFIER"
                                placeholder: "membership ImageID, 64 hex characters"
                                hint: "The membership program this multisig trusts. Committed in the address too, so "
                                      + "naming a permissive verifier just names a multisig nobody funded."
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                PrimaryButton {
                                    text: "Create"
                                    working: root.backendReady && backend.busy
                                    onClicked: {
                                        var words = root.programIdWords(cmVerifier.text)
                                        if (words.length !== 8) {
                                            toast.show("✗ membership verifier: expected the 64-character ImageID "
                                                       + "hex, or eight numbers", root.colError, 7000)
                                            return
                                        }
                                        backend.createMultisig(cmCreator.text.trim(), cmConfigHash.text.trim(),
                                                               cmMemberRoot.text.trim(), parseInt(cmM.text),
                                                               parseInt(cmN.text), cmMultisigId.text.trim(), words)
                                    }
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }

                // ── 3. Create Proposal ──────────────────────────────────
                ScrollView {
                    id: createProposalPage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: createProposalPage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Create Proposal"
                            subtitle: "Proposes a transfer out of the multisig's treasury. Proposal content is public "
                                      + "by design — what stays private is who approves it."
                        }

                        Card {
                            Field {
                                id: cpProposer
                                label: "PROPOSER ACCOUNT"
                                placeholder: "Public/…"
                                hint: "Pays for the transaction. Proposing is not approving, and carries no weight."
                            }
                            Field { id: cpConfigHash; label: "CONFIG HASH"; placeholder: "64 hex characters" }
                            Field {
                                id: cpSeed
                                label: "PROPOSAL SEED"
                                placeholder: "64 hex characters"
                                hint: "Becomes the proposal account's address."
                            }
                            Field { id: cpProposalId; label: "PROPOSAL ID"; placeholder: "64 hex characters" }
                            Field {
                                id: cpRecipient
                                label: "RECIPIENT"
                                placeholder: "Public/…"
                                hint: "Pinned by the proposal: execute refuses to pay anyone else (INV-7)."
                            }
                            Field { id: cpAmount; label: "AMOUNT"; placeholder: "60" }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                PrimaryButton {
                                    text: "Propose"
                                    working: root.backendReady && backend.busy
                                    onClicked: backend.createProposal(cpProposer.text.trim(), cpConfigHash.text.trim(),
                                                                      cpSeed.text.trim(), cpProposalId.text.trim(),
                                                                      cpRecipient.text.trim(), cpAmount.text.trim())
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }

                // ── 4. Approve ──────────────────────────────────────────
                ScrollView {
                    id: approvePage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: approvePage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Approve"
                            subtitle: "Approvals are made with the SDK, not here."
                        }

                        // There is deliberately no witness field on this page. The witness is the member's own
                        // secret material, and this module has no prover: the C ABI builds public transactions,
                        // so anything pasted here would be broadcast in the clear — and the program has no
                        // public approve path to accept it anyway.
                        Card {
                            title: "Why not here"
                            Text {
                                Layout.fillWidth: true
                                text: "An approval is a privacy-preserving transaction. Producing one takes the "
                                      + "prover — about twenty minutes — and the witness that goes into it is your "
                                      + "nullifier secret key. This module submits public transactions, which would "
                                      + "publish that key, so it does not offer to."
                                color: root.colText
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                color: root.colRaised
                                radius: root.radius / 2
                                border.color: root.colBorder
                                border.width: 1
                                implicitHeight: cmdText.implicitHeight + 20
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Text {
                                        id: cmdText
                                        Layout.fillWidth: true
                                        text: "cargo run --release --example wallet_member -- approve"
                                        color: root.colText
                                        font.family: root.mono
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAnywhere
                                    }
                                    CopyButton { value: cmdText.text }
                                }
                            }
                            Note {
                                text: "Once it lands, the Proposal page reads the result back: the approval count "
                                      + "and its nullifiers, and no member identity."
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }

                // ── 5. Execute ──────────────────────────────────────────
                ScrollView {
                    id: executePage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: executePage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Execute"
                            subtitle: "Runs a proposal that has reached its threshold. Anyone may do this, including "
                                      + "a non-member — which is what keeps execution unlinkable to any approver."
                        }

                        Card {
                            Field { id: exConfigHash; label: "CONFIG HASH";   placeholder: "64 hex characters" }
                            Field { id: exSeed;       label: "PROPOSAL SEED"; placeholder: "64 hex characters" }
                            Note {
                                text: "The funds leave the multisig's own account and go to the recipient the "
                                      + "proposal named. A different recipient is refused (error 7012)."
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                PrimaryButton {
                                    text: "Execute"
                                    working: root.backendReady && backend.busy
                                    onClicked: backend.execute(exConfigHash.text.trim(), exSeed.text.trim())
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }

                // ── 6. Accounts ─────────────────────────────────────────
                ScrollView {
                    id: accountsPage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: accountsPage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Accounts"
                            subtitle: "The wallet this module is pointed at, read with LEZ's own wallet binary."
                        }

                        Card {
                            title: "Sequencer"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Text {
                                    Layout.fillWidth: true
                                    text: root.backendReady && backend.connectionStatus.length > 0
                                          ? backend.connectionStatus : "not checked yet"
                                    color: root.colText
                                    font.pixelSize: 12
                                    font.family: root.mono
                                    wrapMode: Text.WrapAnywhere
                                }
                                GhostButton { text: "Check"; onClicked: backend.checkConnection() }
                            }
                        }

                        Card {
                            title: "Wallet accounts"
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: root.backendReady ? backend.walletAccounts.length + " account(s)" : ""
                                    color: root.colMuted
                                    font.pixelSize: 12
                                }
                                GhostButton { text: "Reload"; onClicked: backend.listAccounts() }
                            }
                            EmptyState {
                                visible: root.backendReady && backend.walletAccounts.length === 0
                                message: "No accounts read. Set the wallet path and the wallet CLI directory in "
                                         + "Settings, then press Reload."
                            }
                            Repeater {
                                model: root.backendReady ? backend.walletAccounts : []
                                Rectangle {
                                    Layout.fillWidth: true
                                    color: root.colRaised
                                    radius: root.radius / 2
                                    border.color: root.colBorder
                                    border.width: 1
                                    implicitHeight: accRow.implicitHeight + 16
                                    RowLayout {
                                        id: accRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: 10
                                        spacing: 8
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData["id"] || ""
                                                color: root.colText
                                                font.pixelSize: 12
                                                font.family: root.mono
                                                wrapMode: Text.WrapAnywhere
                                            }
                                            Text {
                                                text: (modelData["status"] || "")
                                                      + (modelData["label"] ? " · " + modelData["label"] : "")
                                                color: root.colMuted
                                                font.pixelSize: 11
                                            }
                                        }
                                        CopyButton { value: modelData["id"] || "" }
                                        GhostButton {
                                            text: "Decode"
                                            implicitWidth: 78
                                            onClicked: backend.decodeAccount(modelData["id"] || "")
                                        }
                                    }
                                }
                            }
                        }

                        Card {
                            title: "Decoded account"
                            EmptyState {
                                visible: !root.backendReady
                                         || Object.keys(backend.walletDecodedAccount).length === 0
                                message: "Press Decode on an account above. A program-owned account comes back as "
                                         + "its named type — a config account decodes to MultisigConfig."
                            }
                            Repeater {
                                model: root.backendReady ? Object.keys(backend.walletDecodedAccount) : []
                                KeyRow {
                                    k: modelData
                                    v: root.asText(backend.walletDecodedAccount[modelData])
                                }
                            }
                        }

                        Card {
                            title: "Inspect an account"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Field {
                                    id: inspectField
                                    label: "ACCOUNT ID"
                                    placeholder: "Public/… or a base58 address"
                                }
                                GhostButton {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 21
                                    text: "Inspect"
                                    onClicked: backend.inspectAccount(inspectField.text.trim())
                                }
                            }
                            Repeater {
                                model: root.backendReady ? Object.keys(backend.walletAccountInfo) : []
                                KeyRow {
                                    k: modelData
                                    mono: false
                                    v: root.asText(backend.walletAccountInfo[modelData])
                                }
                            }
                        }

                        Card {
                            title: "New account"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Field {
                                    id: newAccountLabel
                                    label: "LABEL"
                                    placeholder: "optional"
                                }
                                GhostButton {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 21
                                    text: "Create"
                                    onClicked: backend.createAccount(newAccountLabel.text.trim())
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }

                // ── 7. Settings ─────────────────────────────────────────
                ScrollView {
                    id: settingsPage
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: settingsPage.availableWidth
                        spacing: 16
                        Item { Layout.preferredHeight: 18 }

                        PageHeader {
                            title: "Settings"
                            subtitle: "A fresh install points at nothing. Fill these in before fetching; each field "
                                      + "is saved when you leave it."
                        }

                        Card {
                            title: "Chain"
                            Field {
                                label: "SEQUENCER URL"
                                text: root.backendReady ? backend.sequencerUrl : ""
                                placeholder: "https://testnet.lez.logos.co"
                                hint: "Where accounts are read and transactions are sent."
                                onCommitted: function (value) { backend.setSequencerUrl(value) }
                            }
                            Field {
                                label: "PROGRAM ID (HEX)"
                                text: root.backendReady ? backend.programIdHex : ""
                                placeholder: "64 hex characters"
                                hint: "The deployed multisig program. Every account address is derived from it, so a "
                                      + "wrong value finds nothing rather than failing loudly."
                                onCommitted: function (value) { backend.setProgramIdHex(value) }
                            }
                        }

                        Card {
                            title: "Wallet"
                            Field {
                                label: "WALLET PATH"
                                text: root.backendReady ? backend.walletPath : ""
                                placeholder: "/path/to/wallet"
                                hint: "The wallet directory whose accounts sign transactions."
                                onCommitted: function (value) { backend.setWalletPath(value) }
                            }
                            Field {
                                label: "WALLET CLI DIRECTORY"
                                text: root.backendReady ? backend.walletCliDir : ""
                                placeholder: "/path/to/lez/target/release"
                                hint: "Only the Accounts page needs this: it runs LEZ's own `wallet` binary, which "
                                      + "Basecamp's PATH does not carry."
                                onCommitted: function (value) { backend.setWalletCliDir(value) }
                            }
                        }

                        Item { Layout.preferredHeight: 40 }
                    }
                }
            }
        }

        // ── Toast ────────────────────────────────────────────────────────
        Rectangle {
            id: toast
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 24
            }
            width: Math.min(toastText.implicitWidth + 44, parent.width - 80)
            implicitHeight: Math.max(40, toastText.implicitHeight + 22)
            radius: root.radius / 2
            opacity: 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            function show(msg, col, duration) {
                toastText.text = msg
                toast.color = col
                toast.opacity = 0.97
                toastTimer.interval = duration || 4000
                toastTimer.restart()
            }

            Text {
                id: toastText
                anchors.centerIn: parent
                width: toast.width - 44
                color: "#ffffff"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { toastTimer.stop(); toast.opacity = 0 }
            }
            Timer {
                id: toastTimer
                onTriggered: toast.opacity = 0
            }
        }
    }

    Connections {
        target: backend
        function onOperationSuccess(operation, txHash) {
            toast.show("✓ " + operation + (txHash ? " · " + txHash.slice(0, 12) + "…" : ""),
                       root.colSuccess, 5000)
        }
        function onOperationError(operation, error) {
            toast.show("✗ " + operation + ": " + error, root.colError, 9000)
        }
    }
}
