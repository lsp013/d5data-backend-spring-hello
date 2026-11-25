package com.d5data.springhello.dto;

public record TokenResponse(String token, String tokenType, long expiresIn) {
}
