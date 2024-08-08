use std::fs::OpenOptions;
use std::io::prelude::*;
use clap::Parser;
use rand::Rng;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Username
    #[arg(short, long, default_value = "show_highscore")]
    username: String,

    /// Path to highscore file
    #[arg(short, long, default_value = "highscore.txt")]
    path: String,

    /// Show highscore
    #[arg(short, long)]
    show_highscore: bool,

}

fn validate_highscore_file(path: &str) {
    println!("Validating highscore file at path: {}", path);
    match std::fs::read_to_string(path) {
        Ok(_) => {
            return;
        }
        Err(_) => {
            match std::fs::write(path, "") {
                Ok(_) => {
                    println!("Highscorefile created successfully");
                }
                Err(err) => {
                    eprintln!("Error creating highscore file {}: {}", path, err);
                }
            }
        }
    }
}

fn add_dummy_score(username: &str, path: &str) {
    let mut file = OpenOptions::new()
        .append(true)
        .open(path)
        .unwrap();

    println!("Adding dummy score for user: {}", username);
    let score = rand::thread_rng().gen_range(0..100);
    if let Err(e) = writeln!(file, "{};{}", username, score) {
        eprintln!("Couldn't write to file: {}", e);
    }
}

fn main() {
    let args = Args::parse();
    println!("{:?}", args);

    let username = args.username;
    let path = args.path;
    validate_highscore_file(&path);
    if args.show_highscore {
        println!("Showing highscore");
        let content = std::fs::read_to_string(&path).unwrap();
        println!("{}", content);
        return;
    }
    add_dummy_score(&username, &path)
}
