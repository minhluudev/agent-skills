<?php

namespace Infrastructure\{Domain}\Repositories;

use Domain\{Domain}\Models\{Subject} as Domain{Subject};
use Domain\{Domain}\Repositories\{Subject}Repository;
use Infrastructure\{Domain}\Models\{Subject} as Eloquent{Subject};

class Eloquent{Subject}Repository implements {Subject}Repository
{
    public function findById(int $id): Domain{Subject}
    {
        return $this->toDomain(Eloquent{Subject}::findOrFail($id));
    }

    public function save(Domain{Subject} ${lcSubject}): Domain{Subject}
    {
        $model = ${lcSubject}->id
            ? Eloquent{Subject}::findOrFail(${lcSubject}->id)
            : new Eloquent{Subject}();

        $model->fill([
            'name' => ${lcSubject}->name,
            // TODO: map remaining domain properties to DB columns
        ])->save();

        return $this->toDomain($model);
    }

    public function delete(Domain{Subject} ${lcSubject}): void
    {
        Eloquent{Subject}::findOrFail(${lcSubject}->id)->delete();
    }

    public function findAll(): array
    {
        return Eloquent{Subject}::query()->get()
            ->map(fn ($m) => $this->toDomain($m))
            ->all();
    }

    private function toDomain(Eloquent{Subject} $model): Domain{Subject}
    {
        return new Domain{Subject}(
            id: $model->id,
            name: $model->name,
            // TODO: map remaining DB columns to domain properties
        );
    }
}
