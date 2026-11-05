import QtQuick
import QtTest
import "../../shell/services" as Services
TestCase {
    id:test
    name:"PreferencesReaderRace"
    when:windowShown
    property var saved:null
    function init() {
        const store=Services.SettingsStore;
        saved={acceptWrites:store.acceptWrites,persistedDocument:store.persistedDocument,inflightDocument:store.inflightDocument,writing:store.writing,persistenceState:store.persistenceState,protectFile:store.protectFile,externalReloads:store.externalReloads};
        store.acceptWrites=true;
        store.persistedDocument=store.documentText();
    }
    function cleanup() {
        const store=Services.SettingsStore;
        findChild(store,"settingsSaveDelay").stop();
        store.acceptWrites=false;
        store.writing=false;
        for(const key of Object.keys(saved))store[key]=saved[key];
    }
    function externalDocument() {
        const value=Services.SettingsStore.snapshot();
        value.clock.use24Hour=!value.clock.use24Hour;
        return JSON.stringify(value);
    }
    function test_async_external_read_does_not_clear_inflight_write() {
        const store=Services.SettingsStore,reader=findChild(store,"settingsPreferencesReader");
        store.inflightDocument="retained outgoing writer";store.writing=true;
        const before=store.documentText();
        reader.storedText=externalDocument();reader.loaded();
        compare(store.inflightDocument,"retained outgoing writer");
        compare(store.documentText(),before);
        compare(store.externalReloads,saved.externalReloads);
        compare(store.acceptWrites,true);
    }
    function test_async_external_read_does_not_replace_debounced_draft() {
        const store=Services.SettingsStore,reader=findChild(store,"settingsPreferencesReader");
        const before=store.documentText();
        findChild(store,"settingsSaveDelay").start();
        reader.storedText=externalDocument();reader.loaded();
        compare(store.documentText(),before);
        compare(store.externalReloads,saved.externalReloads);
        compare(store.acceptWrites,true);
    }
    function test_async_read_failure_defers_while_writer_is_active() {
        const store=Services.SettingsStore,reader=findChild(store,"settingsPreferencesReader");
        store.writing=true;store.protectFile=false;store.inflightDocument="pending";
        reader.loadFailed(3);
        compare(store.protectFile,false);
        compare(store.acceptWrites,true);
        compare(store.inflightDocument,"pending");
    }
}
