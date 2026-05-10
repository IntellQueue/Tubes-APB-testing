<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Comment;
use App\Models\History;
use App\Models\Song;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SongController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Song::query()->withCount('comments');

        if ($request->filled('q')) {
            $search = $request->string('q')->toString();
            $query->where(function ($builder) use ($search) {
                $builder->where('title', 'like', "%{$search}%")
                    ->orWhere('artist', 'like', "%{$search}%");
            });
        }

        $songs = $query->latest()->get();
        $likedSongIds = $request->user()->likedSongs()->pluck('songs.id')->all();

        return response()->json([
            'success' => true,
            'data' => $songs->map(fn (Song $song) => $this->songPayload($song, $likedSongIds))->values(),
        ]);
    }

    public function show(Request $request, Song $song): JsonResponse
    {
        $song->loadCount('comments');
        $likedSongIds = $request->user()->likedSongs()->pluck('songs.id')->all();

        return response()->json([
            'success' => true,
            'data' => $this->songPayload($song, $likedSongIds),
        ]);
    }

    public function recordPlay(Request $request, Song $song): JsonResponse
    {
        $song->increment('plays');

        History::updateOrCreate(
            [
                'user_id' => $request->user()->id,
                'song_id' => $song->id,
            ],
            [
                'played_at' => now(),
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Playback tercatat.',
            'data' => [
                'song_id' => $song->id,
                'plays' => $song->fresh()->plays,
            ],
        ]);
    }

    public function toggleLike(Request $request, Song $song): JsonResponse
    {
        $user = $request->user();

        if ($user->likedSongs()->where('song_id', $song->id)->exists()) {
            $user->likedSongs()->detach($song->id);
            $song->decrement('likes');
            $status = 'unliked';
            $message = 'Batal menyukai lagu.';
        } else {
            $user->likedSongs()->attach($song->id);
            $song->increment('likes');
            $status = 'liked';
            $message = 'Lagu disukai.';
        }

        return response()->json([
            'success' => true,
            'status' => $status,
            'message' => $message,
            'data' => [
                'song_id' => $song->id,
                'likes' => $song->fresh()->likes,
            ],
        ]);
    }

    public function comments(Song $song): JsonResponse
    {
        $comments = $song->comments()
            ->whereNull('parent_id')
            ->with([
                'user:id,name',
                'replies' => fn ($query) => $query->with('user:id,name')->latest(),
            ])
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => $comments->map(fn (Comment $comment) => $this->commentPayload($comment))->values(),
        ]);
    }

    public function storeComment(Request $request, Song $song): JsonResponse
    {
        $validated = $request->validate([
            'content' => ['required', 'string', 'max:500'],
            'parent_id' => [
                'nullable',
                'integer',
                Rule::exists('comments', 'id')->where(
                    fn ($query) => $query->where('song_id', $song->id)
                ),
            ],
        ]);

        $comment = Comment::create([
            'user_id' => $request->user()->id,
            'song_id' => $song->id,
            'content' => $validated['content'],
            'parent_id' => $validated['parent_id'] ?? null,
        ]);

        $comment->load('user:id,name');

        return response()->json([
            'success' => true,
            'message' => 'Komentar berhasil ditambahkan.',
            'data' => $this->commentPayload($comment),
        ], 201);
    }

    public function updateComment(Request $request, Comment $comment): JsonResponse
    {
        if ($comment->user_id !== $request->user()->id && $request->user()->role !== 'admin') {
            return response()->json([
                'success' => false,
                'message' => 'Tidak diizinkan mengubah komentar ini.',
            ], 403);
        }

        $validated = $request->validate([
            'content' => ['required', 'string', 'max:500'],
        ]);

        $comment->update(['content' => $validated['content']]);
        $comment->load('user:id,name');

        return response()->json([
            'success' => true,
            'message' => 'Komentar berhasil diperbarui.',
            'data' => $this->commentPayload($comment),
        ]);
    }

    public function destroyComment(Request $request, Comment $comment): JsonResponse
    {
        if ($comment->user_id !== $request->user()->id && $request->user()->role !== 'admin') {
            return response()->json([
                'success' => false,
                'message' => 'Tidak diizinkan menghapus komentar ini.',
            ], 403);
        }

        $comment->delete();

        return response()->json([
            'success' => true,
            'message' => 'Komentar berhasil dihapus.',
        ]);
    }

    public function stream(Song $song)
    {
        $path = public_path($song->file_path);

        if (!file_exists($path)) {
            return response()->json([
                'success' => false,
                'message' => 'File audio tidak ditemukan.',
            ], 404);
        }

        $fileSize = filesize($path);
        $length = $fileSize;
        $start = 0;
        $end = $fileSize - 1;

        $headers = [
            'Content-Type' => mime_content_type($path) ?: 'audio/mpeg',
            'Accept-Ranges' => 'bytes',
        ];

        if (isset($_SERVER['HTTP_RANGE'])) {
            [$unit, $range] = explode('=', $_SERVER['HTTP_RANGE'], 2);

            if ($unit !== 'bytes') {
                return response('', 416);
            }

            if (strpos($range, ',') !== false) {
                $headers['Content-Range'] = "bytes {$start}-{$end}/{$fileSize}";
                return response()->file($path, $headers);
            }

            if ($range === '-') {
                $cStart = $fileSize - (int) substr($range, 1);
                $cEnd = $end;
            } else {
                [$rangeStart, $rangeEnd] = array_pad(explode('-', $range), 2, null);
                $cStart = (int) $rangeStart;
                $cEnd = $rangeEnd !== null && is_numeric($rangeEnd) ? (int) $rangeEnd : $end;
            }

            $cEnd = min($cEnd, $end);

            if ($cStart > $cEnd || $cStart > $fileSize - 1 || $cEnd >= $fileSize) {
                return response('', 416);
            }

            $start = $cStart;
            $end = $cEnd;
            $length = $end - $start + 1;

            $headers['Content-Length'] = $length;
            $headers['Content-Range'] = "bytes {$start}-{$end}/{$fileSize}";

            $stream = fopen($path, 'rb');
            fseek($stream, $start);
            $content = fread($stream, $length);
            fclose($stream);

            return response($content, 206, $headers);
        }

        $headers['Content-Length'] = $length;

        return response()->file($path, $headers);
    }

    private function songPayload(Song $song, array $likedSongIds = []): array
    {
        return [
            'id' => $song->id,
            'title' => $song->title,
            'artist' => $song->artist,
            'description' => $song->description,
            'cover_path' => $song->cover_path,
            'file_path' => $song->file_path,
            'cover_url' => $this->absoluteUrl($song->cover_path),
            'audio_url' => $this->absoluteUrl($song->file_path),
            'stream_url' => route('api.songs.stream', ['song' => $song->id]),
            'plays' => $song->plays,
            'likes' => $song->likes,
            'is_liked' => in_array($song->id, $likedSongIds, true),
            'comments_count' => $song->comments_count ?? $song->comments()->count(),
            'created_at' => $song->created_at,
            'updated_at' => $song->updated_at,
        ];
    }

    private function commentPayload(Comment $comment): array
    {
        return [
            'id' => $comment->id,
            'user_id' => $comment->user_id,
            'song_id' => $comment->song_id,
            'parent_id' => $comment->parent_id,
            'user_name' => $comment->user?->name,
            'content' => $comment->content,
            'created_at' => $comment->created_at,
            'updated_at' => $comment->updated_at,
            'replies' => $comment->relationLoaded('replies')
                ? $comment->replies->map(fn (Comment $reply) => $this->commentPayload($reply))->values()
                : [],
        ];
    }

    private function absoluteUrl(?string $path): ?string
    {
        if (!$path) {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return url(ltrim($path, '/'));
    }
}
