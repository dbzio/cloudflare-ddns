package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	APIToken string
	ZoneID   string
	Domain   string
	RecordID string
	Interval int
}

type IPResponse struct {
	IP string `json:"ip"`
}

type DNSRecord struct {
	Type    string `json:"type"`
	Name    string `json:"name"`
	Content string `json:"content"`
	Proxied bool   `json:"proxied"`
	TTL     int    `json:"ttl"`
}

func main() {
	// Command line flags
	envFile := flag.String("env", ".env", "Path to .env file")
	flag.Parse()

	// Initialize configuration
	config, err := loadConfig(*envFile)
	if err != nil {
		log.Fatalf("Error loading config: %v", err)
	}

	log.Printf("Starting Cloudflare DDNS updater for domain: %s", config.Domain)
	log.Printf("Update interval: %d seconds", config.Interval)

	// Start the update loop
	for {
		if err := updateDNS(config); err != nil {
			log.Printf("Error updating DNS: %v", err)
		}
		time.Sleep(time.Duration(config.Interval) * time.Second)
	}
}

func loadConfig(envFile string) (*Config, error) {
	// Load .env file
	if err := godotenv.Load(envFile); err != nil {
		return nil, fmt.Errorf("error loading .env file: %v", err)
	}

	// Read configuration from environment variables
	config := &Config{
		APIToken: os.Getenv("CLOUDFLARE_API_TOKEN"),
		ZoneID:   os.Getenv("CLOUDFLARE_ZONE_ID"),
		Domain:   os.Getenv("CLOUDFLARE_DOMAIN"),
		RecordID: os.Getenv("CLOUDFLARE_RECORD_ID"),
	}

	// Parse interval with default value
	interval := os.Getenv("UPDATE_INTERVAL")
	if interval == "" {
		config.Interval = 300 // Default to 5 minutes
	} else {
		i, err := strconv.Atoi(interval)
		if err != nil {
			return nil, fmt.Errorf("invalid update interval: %v", err)
		}
		config.Interval = i
	}

	// Validate required fields
	if config.APIToken == "" {
		return nil, fmt.Errorf("CLOUDFLARE_API_TOKEN is required")
	}
	if config.ZoneID == "" {
		return nil, fmt.Errorf("CLOUDFLARE_ZONE_ID is required")
	}
	if config.Domain == "" {
		return nil, fmt.Errorf("CLOUDFLARE_DOMAIN is required")
	}
	if config.RecordID == "" {
		return nil, fmt.Errorf("CLOUDFLARE_RECORD_ID is required")
	}

	return config, nil
}

func getCurrentIP() (string, error) {
	resp, err := http.Get("https://api.ipify.org?format=json")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var ipResp IPResponse
	if err := json.Unmarshal(body, &ipResp); err != nil {
		return "", err
	}

	return ipResp.IP, nil
}

func updateDNS(config *Config) error {
	// Get current IP
	currentIP, err := getCurrentIP()
	if err != nil {
		return fmt.Errorf("error getting current IP: %v", err)
	}

	// Create HTTP client
	client := &http.Client{}

	// Update DNS record
	url := fmt.Sprintf("https://api.cloudflare.com/client/v4/zones/%s/dns_records/%s",
		config.ZoneID, config.RecordID)

	record := DNSRecord{
		Type:    "A",
		Name:    config.Domain,
		Content: currentIP,
		Proxied: false,
		TTL:     1, // Auto TTL
	}

	jsonData, err := json.Marshal(record)
	if err != nil {
		return fmt.Errorf("error marshaling DNS record: %v", err)
	}

	req, err := http.NewRequest(http.MethodPut, url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("error creating request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+config.APIToken)

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("error making request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("error updating DNS record: %s", string(body))
	}

	log.Printf("Successfully updated DNS record for %s to %s", config.Domain, currentIP)
	return nil
}
