_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();

    // load dashboard from file
    click(_link($testUser));
    click(_span("Load Dashboard"));
    screenRegion.find("select_dashboard_file.png").click();
    if(!screenRegion.exists("file_dialog_text_field.png", 1)) {
        screenRegion.find("file_dialog_text_button.png").click();
    }
    screenRegion.find("file_dialog_text_field.png").click();
    env.type("/thruk/all_in_one.tab");
    screenRegion.find("file_dialog_button_open.png").click();

    click(_link("Import"));
    isVisible(_paragraph("dashboard loaded successfully."));

    // check if status data is immediatly updated
    isVisible(_link("Host Icon"));
    isVisible(_link("Label Only x=5"));

    thruk_remove_panorama_dashboard("All In One");

    testCase.endOfStep("panorama all in one", 90);
};

runTest($case);
