<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HistoryController;
use App\Http\Controllers\Api\PlaylistController;
use App\Http\Controllers\Api\SongController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register'])->name('api.register');
Route::post('/login', [AuthController::class, 'login'])->name('api.login');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me'])->name('api.me');
    Route::post('/profile', [AuthController::class, 'updateProfile'])->name('api.profile.update');
    Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');

    Route::get('/songs', [SongController::class, 'index'])->name('api.songs.index');
    Route::get('/songs/{song}', [SongController::class, 'show'])->name('api.songs.show');
    Route::get('/songs/{song}/stream', [SongController::class, 'stream'])->name('api.songs.stream');
    Route::post('/songs/{song}/record-play', [SongController::class, 'recordPlay'])->name('api.songs.recordPlay');
    Route::post('/songs/{song}/like', [SongController::class, 'toggleLike'])->name('api.songs.like');
    Route::get('/songs/{song}/comments', [SongController::class, 'comments'])->name('api.songs.comments.index');
    Route::post('/songs/{song}/comments', [SongController::class, 'storeComment'])->name('api.songs.comments.store');

    Route::put('/comments/{comment}', [SongController::class, 'updateComment'])->name('api.comments.update');
    Route::delete('/comments/{comment}', [SongController::class, 'destroyComment'])->name('api.comments.destroy');

    Route::get('/playlists', [PlaylistController::class, 'index'])->name('api.playlists.index');
    Route::post('/playlists', [PlaylistController::class, 'store'])->name('api.playlists.store');
    Route::put('/playlists/{playlist}', [PlaylistController::class, 'update'])->name('api.playlists.update');
    Route::delete('/playlists/{playlist}', [PlaylistController::class, 'destroy'])->name('api.playlists.destroy');

    Route::get('/history', [HistoryController::class, 'index'])->name('api.history.index');
});
