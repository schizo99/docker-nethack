fn main() {
    let output = std::process::Command::new("/nh367/nethack")
        .arg("-s")
        .output()
        .expect("failed to execute process");
    print!("\x1B[2J\x1B[1;1H");
    println!("{}", String::from_utf8_lossy(&output.stdout));
    println!("<More>");
    print!("\x1B[?25l");
    let mut input = String::new();
    std::io::stdin().read_line(&mut input).unwrap();
    print!("\x1B[?25h");
}
