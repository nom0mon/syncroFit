<?php

namespace Tests\Feature\Property;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Property Test: Registration Validation Field Specificity (Property 7)
 *
 * For random invalid registration payloads, verify 422 response has errors
 * only for invalid fields; valid fields are absent from the errors object.
 *
 * **Validates: Requirements 1.3**
 */
class RegistrationValidationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Property 7: Registration Validation Field Specificity
     *
     * Generate random payloads where some fields are valid and some are invalid.
     * Verify the errors object only contains keys for the invalid fields.
     *
     * Valid ranges: name 1-50 chars, email valid+unique+<=254, password 8-128 chars
     *
     * **Validates: Requirements 1.3**
     */
    public function test_registration_validation_field_specificity_property(): void
    {
        for ($i = 0; $i < 50; $i++) {
            // Decide which fields will be invalid (at least one must be invalid)
            $invalidFields = $this->randomInvalidFieldSubset();

            // Generate payload with the selected invalid/valid field combination
            $payload = $this->generatePayload($invalidFields);

            $response = $this->postJson('/api/register', $payload['data']);

            $response->assertStatus(422, "Iteration $i: Expected 422 for invalid fields: " . implode(', ', $invalidFields));

            $errors = $response->json('errors');

            $this->assertNotNull($errors, "Iteration $i: Errors object should not be null for invalid payload");

            // Verify errors contain keys ONLY for invalid fields
            foreach ($invalidFields as $field) {
                $this->assertArrayHasKey(
                    $field,
                    $errors,
                    "Iteration $i: Expected error key '$field' to be present. "
                    . "Invalid fields: [" . implode(', ', $invalidFields) . "], "
                    . "Payload: " . json_encode($payload['data'])
                );
            }

            // Verify valid fields are NOT in errors
            foreach ($payload['validFields'] as $field) {
                $this->assertArrayNotHasKey(
                    $field,
                    $errors,
                    "Iteration $i: Valid field '$field' should NOT appear in errors. "
                    . "Invalid fields: [" . implode(', ', $invalidFields) . "], "
                    . "Errors: " . json_encode($errors)
                );
            }
        }
    }

    /**
     * Select a random non-empty subset of fields to make invalid.
     *
     * @return array<string>
     */
    private function randomInvalidFieldSubset(): array
    {
        $allFields = ['name', 'email', 'password'];

        // Generate a random bitmask (1-7) to select which fields are invalid
        // At least one field must be invalid (exclude 0)
        $bitmask = mt_rand(1, 7);

        $invalidFields = [];
        foreach ($allFields as $index => $field) {
            if ($bitmask & (1 << $index)) {
                $invalidFields[] = $field;
            }
        }

        return $invalidFields;
    }

    /**
     * Generate a registration payload with specified invalid fields.
     *
     * @param array<string> $invalidFields
     * @return array{data: array, validFields: array<string>}
     */
    private function generatePayload(array $invalidFields): array
    {
        $data = [];
        $validFields = [];

        // Name: valid = 1-50 chars, invalid = empty or >50 chars
        if (in_array('name', $invalidFields)) {
            $data['name'] = $this->generateInvalidName();
        } else {
            $data['name'] = $this->generateValidName();
            $validFields[] = 'name';
        }

        // Email: valid = proper format + unique + <=254 chars, invalid = bad format or >254 chars
        if (in_array('email', $invalidFields)) {
            $data['email'] = $this->generateInvalidEmail();
        } else {
            $data['email'] = $this->generateValidUniqueEmail();
            $validFields[] = 'email';
        }

        // Password: valid = 8-128 chars, invalid = <8 or >128 chars
        if (in_array('password', $invalidFields)) {
            $data['password'] = $this->generateInvalidPassword();
        } else {
            $data['password'] = $this->generateValidPassword();
            $validFields[] = 'password';
        }

        return ['data' => $data, 'validFields' => $validFields];
    }

    private function generateValidName(): string
    {
        $length = mt_rand(1, 50);
        return $this->randomString($length);
    }

    private function generateInvalidName(): string
    {
        // Randomly pick an invalid name strategy
        $strategy = mt_rand(0, 1);

        return match ($strategy) {
            0 => '', // empty name
            1 => $this->randomString(mt_rand(51, 100)), // too long
        };
    }

    private function generateValidUniqueEmail(): string
    {
        // Generate a unique valid email with random local part
        $localPart = $this->randomAlphanumeric(mt_rand(3, 20));
        $domain = $this->randomAlphanumeric(mt_rand(3, 10)) . '.com';
        return $localPart . '@' . $domain;
    }

    private function generateInvalidEmail(): string
    {
        // Randomly pick an invalid email strategy
        $strategy = mt_rand(0, 2);

        return match ($strategy) {
            0 => $this->randomString(mt_rand(5, 15)), // no @ sign
            1 => '@' . $this->randomAlphanumeric(5) . '.com', // missing local part
            2 => $this->randomAlphanumeric(200) . '@' . $this->randomAlphanumeric(50) . '.com', // >254 chars
        };
    }

    private function generateValidPassword(): string
    {
        $length = mt_rand(8, 128);
        return $this->randomAlphanumeric($length);
    }

    private function generateInvalidPassword(): string
    {
        // Randomly pick an invalid password strategy
        $strategy = mt_rand(0, 1);

        return match ($strategy) {
            0 => $this->randomAlphanumeric(mt_rand(1, 7)), // too short
            1 => $this->randomAlphanumeric(mt_rand(129, 200)), // too long
        };
    }

    private function randomString(int $length): string
    {
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
        $result = '';
        for ($i = 0; $i < $length; $i++) {
            $result .= $chars[mt_rand(0, strlen($chars) - 1)];
        }
        return $result;
    }

    private function randomAlphanumeric(int $length): string
    {
        $chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        $result = '';
        for ($i = 0; $i < $length; $i++) {
            $result .= $chars[mt_rand(0, strlen($chars) - 1)];
        }
        return $result;
    }
}
