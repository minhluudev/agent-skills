<?php

namespace Infrastructure\{Domain}\Models;

use Domain\{Domain}\Collections\{Subject}Collection;
use Domain\{Domain}\QueryBuilders\{Subject}QueryBuilder;
use Illuminate\Database\Eloquent\Model;

class {Subject} extends Model
{
    protected $table = '{table}';

    protected $fillable = [
        'name',
        // TODO: add fillable columns
    ];

    protected $casts = [
        // TODO: add casts (e.g., 'is_active' => 'boolean', 'published_at' => 'datetime')
    ];

    public function newEloquentBuilder($query): {Subject}QueryBuilder
    {
        return new {Subject}QueryBuilder($query);
    }

    public function newCollection(array $models = []): {Subject}Collection
    {
        return new {Subject}Collection($models);
    }
}
