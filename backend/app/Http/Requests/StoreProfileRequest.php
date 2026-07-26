<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreProfileRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'age' => ['required', 'integer', 'min:13', 'max:120'],
            'height_cm' => ['required', 'numeric', 'min:50', 'max:300'],
            'weight_kg' => ['required', 'numeric', 'min:20', 'max:500'],
            'gender' => ['required', 'string', 'in:male,female,other'],
            'goal' => ['required', 'string', 'in:lose_weight,build_muscle,stay_fit,increase_stamina'],
            'fitness_level' => ['required', 'string', 'in:beginner,intermediate,advanced'],
            'workout_preference' => ['required', 'string', 'in:home,gym,outdoor'],
            'availability_days' => ['required', 'array', 'min:1', 'max:7'],
            'availability_days.*' => ['string', 'in:monday,tuesday,wednesday,thursday,friday,saturday,sunday'],
        ];
    }
}
