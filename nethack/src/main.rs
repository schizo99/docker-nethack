use console::Term;
fn main() {
    let term = Term::stdout();
    let output = std::process::Command::new("/nh367/nethack")
        .arg("-s")
        .output()
        .expect("failed to execute process");
    let result = std::str::from_utf8(&output.stdout).expect("Failed to convert output to string");
    term.clear_screen().expect("Failed to clear terminal");
    term.hide_cursor().expect("Failed to hide cursor");
    term.write_line(result).expect("Failed to write to terminal");
    term.write_line("<More>").expect("Failed to write to terminal");
    term.read_key().expect("Failed to read key");
    term.show_cursor().expect("Failed to show cursor");
}
